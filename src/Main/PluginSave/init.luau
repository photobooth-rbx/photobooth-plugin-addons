local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Bufferize = require(pluginRoot.Packages.Bufferize)

local SaveVersions = require(script.SaveVersions)

local PluginSave = {}
local currentDeserialized = SaveVersions.load({
	version = SaveVersions.latest.version,
	serialized = {},
})

function PluginSave.read()
	return currentDeserialized
end

function PluginSave.mutate(mutation: (SaveVersions.Deserialized) -> SaveVersions.Deserialized)
	local result = mutation(currentDeserialized)
	currentDeserialized = result
end

function PluginSave.setup(plugin: Plugin)
	local pluginSetting = plugin:GetSetting("egomoose_photobooth_addon")
	if pluginSetting then
		local decodedSave = Bufferize.decode(pluginSetting)
		currentDeserialized = SaveVersions.load(decodedSave)
	end

	plugin.Unloading:Connect(function()
		local save = SaveVersions.save(currentDeserialized)
		local encoded = Bufferize.encode(save)
		plugin:SetSetting("egomoose_photobooth_addon", encoded)
	end)
end

return PluginSave
