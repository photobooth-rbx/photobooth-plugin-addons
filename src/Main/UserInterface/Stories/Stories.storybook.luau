local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

return {
	name = "PhotoboothAddon",
	storyRoots = {
		script:FindFirstAncestor("UserInterface").Apps,
	},
	packages = {
		React = React,
		ReactRoblox = ReactRoblox,
	},
}
