local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

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

export type StrokeLayer = GenericLayer<"Stroke", StrokeProperties>
export type DropShadowLayer = GenericLayer<"Drop Shadow", DropShadowProperties>
export type Layer = StrokeLayer | DropShadowLayer

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.observableLayers = ObservableValue.new({})

	return self
end

-- Private

local registeredKinds = {}
local createProperties = {}
local createPropertiesByKind = {}

local function registerPropertyKind<T>(kind: string, create: () -> T)
	local entry = {
		index = #createProperties + 1,
		kind = kind,
		create = create,
	}

	table.insert(registeredKinds, entry.kind)
	table.insert(createProperties, entry)
	createPropertiesByKind[kind] = entry
end

registerPropertyKind("Stroke", function()
	local properties: StrokeProperties = {
		thickness = 0,
		softness = 1,
		transparency = 0,
		color = Color3.new(0, 0, 0),
	}
	return properties
end)

registerPropertyKind("Drop Shadow", function()
	local properties: DropShadowProperties = {
		transparency = 1,
		color = Color3.new(0, 0, 0),
		offset = Vector2.zero,
		spread = 0,
		blur = 0,
	}
	return properties
end)

-- Public

function PostProcessingControllerClass.getKinds(self: PostProcessingController)
	return registeredKinds
end

function PostProcessingControllerClass.createLayer(self: PostProcessingController, kind: string, name: string)
	local entry = assert(createPropertiesByKind[kind])
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

function PostProcessingControllerClass.use(self: PostProcessingController)
	return self.observableLayers:use()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.observableLayers:Destroy()
end

--

return PostProcessingControllerStatic
