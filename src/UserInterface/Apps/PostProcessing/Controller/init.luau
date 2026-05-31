local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Trove = require(pluginRoot.Packages.Trove)

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

type Registration<Properties> = {
	public: boolean,
	create: () -> Properties,
	render: (GenericEffect<string, Properties>) -> (),
	update: (GenericEffect<string, Properties>) -> (),
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
		update = registration.update,
	}
end

registerKind("Base Image", {
	public = false,
	create = function()
		local properties: BaseImageProperties = {
			transparency = 0,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function() end,
	update = function() end,
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
	render = function() end,
	update = function() end,
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
	render = function() end,
	update = function() end,
})

-- Class

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		imageTrove: Trove.Trove,
		observableEffects: ObservableValue.ObservableValue<{ Effect }>,
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.imageTrove = Trove.new()
	self.observableEffects = ObservableValue.new({})
	self.observableLayers = ObservableValue.new({})

	self:createEffect("Base Image", "Image")

	return self
end

-- Public

function PostProcessingControllerClass.isEffectPublic(self: PostProcessingController, kind: string)
	local entry = assert(registeredByKind[kind])
	return entry.public
end

function PostProcessingControllerClass.getPublicEffectKinds(self: PostProcessingController)
	return registeredPublicKinds
end

function PostProcessingControllerClass.createEffect(self: PostProcessingController, kind: string, name: string)
	local entry = assert(registeredByKind[kind])
	local effect = {
		kind = kind,
		name = name,
		renderTicket = 0,
		properties = entry.create(),
	}

	self.observableEffects:update()(function(effects)
		table.insert(effects, effect :: any)
		return effects
	end)
end

function PostProcessingControllerClass.useEffects(self: PostProcessingController)
	return self.observableEffects:use()
end

function PostProcessingControllerClass.loadImageAsync(self: PostProcessingController, editImage: EditableImage)
	-- load the image in
	-- render each of the layers
	self.observableLayers:set({
		{
			EditImage = editImage,
			TintColor = Color3.new(1, 1, 1),
			Transparency = 0,
		},
	})

	self.imageTrove:Add(function()
		self.observableLayers:set({})
	end)
end

function PostProcessingControllerClass.unloadImage(self: PostProcessingController)
	self.imageTrove:Clean()
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
