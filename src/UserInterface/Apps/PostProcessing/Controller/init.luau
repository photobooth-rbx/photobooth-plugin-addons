local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Future = require(pluginRoot.Packages.Future)
local Signal = require(pluginRoot.Packages.Signal)
local Trove = require(pluginRoot.Packages.Trove)

local SignedVectorField = require(script.SignedVectorField)

export type BaseImageProperties = {
	transparency: number,
	color: Color3,
}

export type StrokeProperties = {
	thickness: number,
	softness: number,
	transparency: number,
	color: Color3,
}

export type DropShadowProperties = {
	blur: number,
	spread: number,
	offset: Vector2,
	transparency: number,
	color: Color3,
}

type GenericEffect<Kind, Properties> = {
	kind: Kind,
	name: string,
	index: number,
	renderTicket: number,
	properties: Properties,
}

export type BaseImageEffect = GenericEffect<"Base Image", BaseImageProperties>
export type StrokeEffect = GenericEffect<"Stroke", StrokeProperties>
export type DropShadowEffect = GenericEffect<"Drop Shadow", DropShadowProperties>
export type Effect = BaseImageEffect | StrokeEffect | DropShadowEffect

export type Layer = {
	EditImage: EditableImage,
	TintColor: Color3,
	Transparency: number,
}

type ImageInputs = {
	base: EditableImage,
	svf: EditableImage,
	output: EditableImage,
}

type Registration<Properties> = {
	public: boolean,
	create: () -> Properties,
	render: (ImageInputs, Properties) -> (),
}

local registeredKinds = {}
local registeredPublicKinds = {}
local registeredByKind = {}

local function registerKind<Properties>(kind: string, registration: Registration<Properties>)
	table.insert(registeredKinds, kind)
	if registration.public then
		table.insert(registeredPublicKinds, kind)
	end

	registeredByKind[kind] = {
		kind = kind,
		index = #registeredKinds,
		public = registration.public,
		create = registration.create,
		render = registration.render,
	}
end

registerKind("Base Image", {
	public = false,
	create = function()
		local properties: BaseImageProperties = {
			transparency = 0,
			color = Color3.new(1, 1, 1),
		}
		return properties
	end,
	render = function(inputs, properties) end,
})

registerKind("Stroke", {
	public = true,
	create = function()
		local properties: StrokeProperties = {
			thickness = 0,
			softness = 1,
			transparency = 0,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties) end,
})

registerKind("Drop Shadow", {
	public = true,
	create = function()
		local properties: DropShadowProperties = {
			transparency = 1,
			color = Color3.new(0, 0, 0),
			offset = Vector2.zero,
			spread = 0,
			blur = 0,
		}
		return properties
	end,
	render = function(inputs, properties)
		local size = inputs.output.Size
		local b = inputs.output:ReadPixelsBuffer(Vector2.zero, size)
		for i = 1, size.X * size.Y do
			local j = (i - 1) * 4
			buffer.writeu8(b, j + 0, 0)
			buffer.writeu8(b, j + 1, 0)
			buffer.writeu8(b, j + 2, 0)
			buffer.writeu8(b, j + 3, 255)
		end
		inputs.output:WritePixelsBuffer(Vector2.zero, size, b)
	end,
})

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

function PostProcessingControllerClass.isEffectPublic(self: PostProcessingController, kind: string)
	local effectEntry = assert(registeredByKind[kind])
	return effectEntry.public
end

function PostProcessingControllerClass.getPublicEffectKinds(self: PostProcessingController)
	return registeredPublicKinds
end

function PostProcessingControllerClass.createEffect(self: PostProcessingController, kind: string, name: string)
	local effectEntry = assert(registeredByKind[kind])
	local observableEffect = ObservableValue.new({
		kind = kind,
		name = name,
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
		if not isImageLoaded:isCompleted() then
			isImageLoaded:complete()
		end
	end)

	self.imageTrove:Add(task.spawn(function()
		local svfEdit = SignedVectorField.generateAsync(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			svfEdit:Destroy()
		end)

		local function watchEffect(observedEffect: ObservableValue.ObservableValue<Effect>)
			local renderReady = Future.new()

			local effect = observedEffect:get()
			local effectEntry = registeredByKind[effect.kind]

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
