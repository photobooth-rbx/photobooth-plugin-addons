local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local Effects = require(script.Effects)
local SignedVectorField = require(script.Helpers.SignedVectorField)

-- Types

type GenericEffect<Kind, Properties> = {
	kind: Kind,
	name: string,
	index: number,
	playerCreated: boolean,
	renderTicket: number,
	properties: Properties,
}

export type BaseImageEffect = GenericEffect<"Base Image", Effects.BaseImageProperties>
export type StrokeEffect = GenericEffect<"Stroke", Effects.StrokeProperties>
export type DropShadowEffect = GenericEffect<"Drop Shadow", Effects.DropShadowProperties>
export type Effect = BaseImageEffect | StrokeEffect | DropShadowEffect

export type Layer = {
	EditImage: EditableImage,
	TintColor: Color3,
	Transparency: number,
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

		observableEffects: ObservableValue.ObservableValue<{ ObservableValue.ObservableValue<Effect> }>,
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
		local t = os.clock()
		local svfEdit = SignedVectorField.generateParallelAsync(Content.fromObject(editImage))
		print(os.clock() - t)
		self.imageTrove:Add(function()
			svfEdit:Destroy()
		end)

		local function watchEffect(observedEffect: ObservableValue.ObservableValue<Effect>)
			local renderReady = Future.new()

			local effect = observedEffect:get()
			local effectEntry = Effects.getByKind(effect.kind)

			local layer: Layer = {
				EditImage = AssetService:CreateEditableImageAsync(Content.fromObject(editImage)),
				TintColor = effect.properties.color,
				Transparency = effect.properties.transparency,
			}

			local inputs = {
				base = editImage,
				svf = svfEdit,
				output = layer.EditImage,
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

					layer.TintColor = effect.properties.color
					layer.Transparency = effect.properties.transparency

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
				layer.EditImage:Destroy()
				if not renderReady:isCompleted() then
					renderReady:complete()
				end
			end

			return renderReady, cleanup
		end

		local watching = {}
		self.imageTrove:Add(function()
			for observableEffect, cleanup in watching do
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

			for observableEffect, cleanup in watching do
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
	-- compose
	self:unloadImage()
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
