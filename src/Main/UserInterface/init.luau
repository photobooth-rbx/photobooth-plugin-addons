local AutoCapture = require(script.Apps.AutoCapture)
local PostProcessing = require(script.Apps.PostProcessing)

local UserInterface = {}

function UserInterface.mount(plugin: Plugin, toolbar: PluginToolbar)
	AutoCapture.mount(plugin, toolbar)
	PostProcessing.mount(plugin, toolbar)
end

return UserInterface
