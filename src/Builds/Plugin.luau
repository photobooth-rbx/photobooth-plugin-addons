local pluginRoot = script:FindFirstAncestor("PluginRoot")
local UserInterface = require(pluginRoot.Main.UserInterface)
local PluginSave = require(pluginRoot.Main.PluginSave)

local Plugin = {}

-- Public

function Plugin.build(plugin: Plugin)
	-- Load persisted state (and arrange to save it on unload) before any UI/controller
	-- reads it.
	PluginSave.setup(plugin)

	local toolbar = plugin:CreateToolbar("Photobooth Post Processing")
	UserInterface.mount(plugin, toolbar)
end

return Plugin
