local EncodingService = game:GetService("EncodingService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Bufferize = require(pluginRoot.Packages.Bufferize)

local SETTING_KEY = "egomoose_photobooth_addon"

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
	local pluginSetting = plugin:GetSetting(SETTING_KEY) :: string?
	if pluginSetting then
		pcall(function()
			local encoded = EncodingService:Base64Decode(buffer.fromstring(pluginSetting))
			local decodedSave = Bufferize.decode(encoded)
			currentDeserialized = SaveVersions.load(decodedSave)
		end)
	end

	plugin.Unloading:Connect(function()
		local save = SaveVersions.save(currentDeserialized)
		local encoded = EncodingService:Base64Encode(Bufferize.encode(save))
		plugin:SetSetting(SETTING_KEY, buffer.tostring(encoded))
	end)
end

return PluginSave
