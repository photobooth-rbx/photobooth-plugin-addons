local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local Effects = require(script.Effects)
local LayerComposer = require(script.LayerComposer)
local SignedVectorField = require(script.SignedVectorField)

-- Types

export type Layer = LayerComposer.Layer

export type Effect<Properties> = {
	kind: string,
	name: string,
	index: number,
	playerCreated: boolean,
	renderTicket: number,
	properties: Properties,
}

-- Class

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		editImage: EditableImage?,
		imageTrove: Trove.Trove,

		observableEffects: ObservableValue.ObservableValue<{ ObservableValue.ObservableValue<Effect<any>> }>,
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.editImage = nil
	self.imageTrove = Trove.new()

	self.observableEffects = ObservableValue.new({})
	self.observableLayers = ObservableValue.new({})

	self:createEffect("Base Image", "Image")

	return self
end

function PostProcessingControllerStatic.loadingLayer(editImage: EditableImage)
	local layer: Layer = {
		name = "Image",
		editImage = editImage,
		offset = Vector2.zero,
		tintColor = Color3.new(1, 1, 1),
		transparency = 0,
	}

	return layer
end

-- Public

function PostProcessingControllerClass.createEffect(self: PostProcessingController, kind: string, name: string)
	local effectEntry = assert(Effects.getByKind(kind))
	local observableEffect = ObservableValue.new({
		kind = kind,
		name = name,
		playerCreated = effectEntry.playerCreated,
		index = #self.observableEffects:get() + 1,
		renderTicket = 0,
		properties = effectEntry.create(),
	})

	self.observableEffects:update()(function(effects)
		table.insert(effects, observableEffect :: any)
		return effects
	end)
end

function PostProcessingControllerClass.useEffects(self: PostProcessingController)
	return self.observableEffects:use()
end

function PostProcessingControllerClass.loadImageAsync(self: PostProcessingController, editImage: EditableImage)
	if self.editImage == editImage then
		return
	end

	self:unloadImage()
	self.editImage = editImage

	local isImageLoaded = Future.new()

	self.imageTrove:Add(function()
		self.observableLayers:set({})
		if not isImageLoaded:isCompleted() then
			isImageLoaded:complete()
		end
	end)

	self.imageTrove:Add(task.spawn(function()
		local svfProcess = SignedVectorField.generate(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			svfProcess:cancel()
		end)

		local unpackSvfEdit = svfProcess:expect()
		if not unpackSvfEdit then
			return
		end

		local svfEdit = unpackSvfEdit()
		self.imageTrove:Add(function()
			svfEdit:Destroy()
		end)

		local function watchEffect(observedEffect: ObservableValue.ObservableValue<Effect<any>>)
			local renderReady = Future.new()

			local effect = observedEffect:get()
			local effectEntry = Effects.getByKind(effect.kind)

			local layer: Layer = {
				name = effect.name,
				editImage = AssetService:CreateEditableImageAsync(Content.fromObject(editImage)),
				offset = effect.properties.offset,
				tintColor = effect.properties.color,
				transparency = effect.properties.transparency,
			}

			local inputs: Effects.ImageInputs = {
				img = editImage,
				svf = svfEdit,
				output = layer.editImage,
			}

			local watchTrove = Trove.new()
			local asyncTrove = Trove.new()

			local renderTicket = effect.renderTicket
			watchTrove:Add(observedEffect:onChanged(function()
				asyncTrove:Clean()
				asyncTrove:Add(task.spawn(function()
					local newRenderTicket = effect.renderTicket
					if newRenderTicket ~= renderTicket then
						renderTicket = newRenderTicket
						effectEntry.render(inputs, effect.properties :: any)
						if not renderReady:isCompleted() then
							renderReady:complete()
						end
					end

					layer.name = effect.name
					layer.offset = effect.properties.offset
					layer.tintColor = effect.properties.color
					layer.transparency = effect.properties.transparency

					self.observableLayers:update()(function(layers)
						layers[effect.index] = layer
						return layers
					end)
				end))
			end))

			asyncTrove:Add(task.spawn(function()
				effectEntry.render(inputs, effect.properties :: any)
				if not renderReady:isCompleted() then
					renderReady:complete()
				end
			end))

			self.observableLayers:update()(function(layers)
				layers[effect.index] = layer
				return layers
			end)

			local function cleanup()
				watchTrove:Destroy()
				asyncTrove:Destroy()
				layer.editImage:Destroy()
				if not renderReady:isCompleted() then
					renderReady:complete()
				end
			end

			return renderReady, cleanup
		end

		local watching = {}
		self.imageTrove:Add(function()
			for _observableEffect, cleanup in watching do
				local cleanupCasted = cleanup :: () -> ()
				cleanupCasted()
			end
		end)

		for _, observedEffect in self.observableEffects:get() do
			local renderReady, cleanup = watchEffect(observedEffect :: any)
			watching[observedEffect] = cleanup
			renderReady:expect()
		end

		self.imageTrove:Add(self.observableEffects:onChanged(function()
			local newWatching = {}
			for _, observedEffect in self.observableEffects:get() do
				if watching[observedEffect] then
					newWatching[observedEffect] = watching[observedEffect]
				else
					local _renderReady, cleanup = watchEffect(observedEffect :: any)
					newWatching[observedEffect] = cleanup
				end
				watching[observedEffect] = nil
			end

			for _observableEffect, cleanup in watching do
				cleanup()
			end

			watching = newWatching
		end))

		if not isImageLoaded:isCompleted() then
			isImageLoaded:complete()
		end
	end))

	return isImageLoaded:expect()
end

function PostProcessingControllerClass.unloadImage(self: PostProcessingController)
	self.imageTrove:Clean()
	self.editImage = nil
end

function PostProcessingControllerClass.composeImageAsync(self: PostProcessingController, editImage: EditableImage)
	self:loadImageAsync(editImage)

	local layers = self.observableLayers:get()
	local composedEdit = LayerComposer.composeAsync(editImage, layers)

	self:unloadImage()

	return composedEdit
end

function PostProcessingControllerClass.useLayers(self: PostProcessingController)
	return self.observableLayers:use()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.imageTrove:Destroy()
	self.observableEffects:Destroy()
	self.observableLayers:Destroy()
end

--

return PostProcessingControllerStatic
