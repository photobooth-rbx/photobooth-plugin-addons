local pluginRoot = script:FindFirstAncestor("PluginRoot")
local UserInterface = require(pluginRoot.Main.UserInterface)

local Plugin = {}

-- Public

function Plugin.build(plugin: Plugin)
	local toolbar = plugin:CreateToolbar("Photobooth Post Processing")
	UserInterface.mount(plugin, toolbar)
end

return Plugin
