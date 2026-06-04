local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Sift = require(pluginRoot.Packages.Sift)

export type Serialized = {}

export type Deserialized = {}

local SaveFormatV1 = {}
SaveFormatV1.version = 1

function SaveFormatV1.default(): Deserialized
	return {}
end

function SaveFormatV1.migrate(_previousSerialized: any)
	error(`[SaveFormatV{SaveFormatV1.version}]: Cannot migrate from V1`)
end

function SaveFormatV1.serialize(_deserialized: Deserialized): Serialized
	return {}
end

function SaveFormatV1.deserialize(_serialized: Serialized): Deserialized
	return Sift.Dictionary.mergeDeep(SaveFormatV1.default(), {})
end

return SaveFormatV1
