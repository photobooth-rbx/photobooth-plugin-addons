local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)

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

type GenericLayer<Kind, Properties> = {
	kind: Kind,
	name: string,
	renderTicket: number,
	properties: Properties,
}

export type BaseImageLayer = GenericLayer<"Base Image", BaseImageProperties>
export type StrokeLayer = GenericLayer<"Stroke", StrokeProperties>
export type DropShadowLayer = GenericLayer<"Drop Shadow", DropShadowProperties>
export type Layer = BaseImageLayer | StrokeLayer | DropShadowLayer

type Registration<Properties> = {
	public: boolean,
	create: () -> Properties,
	render: (GenericLayer<string, Properties>) -> (),
	update: (GenericLayer<string, Properties>) -> (),
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
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.observableLayers = ObservableValue.new({})
	self:createLayer("Base Image", "Image")

	return self
end

-- Public

function PostProcessingControllerClass.isPublic(self: PostProcessingController, kind: string)
	local entry = assert(registeredByKind[kind])
	return entry.public
end

function PostProcessingControllerClass.getPublicKinds(self: PostProcessingController)
	return registeredPublicKinds
end

function PostProcessingControllerClass.createLayer(self: PostProcessingController, kind: string, name: string)
	local entry = assert(registeredByKind[kind])
	local layer = {
		kind = kind,
		name = name,
		renderTicket = 0,
		properties = entry.create(),
	}

	self.observableLayers:update()(function(layers)
		table.insert(layers, layer :: any)
		return layers
	end)
end

function PostProcessingControllerClass.useLayers(self: PostProcessingController)
	return self.observableLayers:use()
end

function PostProcessingControllerClass.loadImageAsync(self: PostProcessingController, editImage: EditableImage)
	-- load the image in
	-- render each of the layers
end

function PostProcessingControllerClass.unloadImage(self: PostProcessingController)
	-- unload the image
end

function PostProcessingControllerClass.composeImageAsync(self: PostProcessingController, editImage: EditableImage)
	self:loadImageAsync(editImage)
	-- compose
	self:unloadImage()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.observableLayers:Destroy()
end

--

return PostProcessingControllerStatic
