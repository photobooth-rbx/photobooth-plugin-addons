local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ButtonIcon = require(uiRoot.ButtonIcon)
local Hooks = require(uiRoot.Hooks)

local Widget = require(script.Components.Widget)
local Controller = require(script.Controller)

local PostProcessing = {}

function PostProcessing.mount(plugin: Plugin, toolbar: PluginToolbar)
	-- stylua: ignore
	local button = toolbar:CreateButton(
		"egomoose_photobooth_addon_post_processing", 
		"Photobooth Post Processing", "", "Effects"
	)

	ButtonIcon.listen(button, "sparkles")

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 750, 450, 750, 450)
	local dock = plugin:CreateDockWidgetPluginGuiAsync("egomoose_photobooth_addon_post_processing", info)
	dock.Name = "Photobooth Post Processing"
	dock.Title = "Photobooth - Post Processing"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function App()
		local dockRef = React.useRef(dock)
		local isEnabled = Hooks.useRefProperty(dockRef, "Enabled", false)

		dock.Enabled = isEnabled
		button:SetActive(isEnabled)

		React.useEffect(function()
			local onClick = button.Click:Connect(function()
				dock.Enabled = not dock.Enabled
			end)

			return function()
				onClick:Disconnect()
			end
		end, {})

		return React.createElement(Widget, {
			Disabled = false,
		})
	end

	local dockRoot = ReactRoblox.createRoot(dock)
	dockRoot:render(React.createElement(StudioProperties.PluginContext.Provider, {
		value = plugin,
	}, {
		ComponentsPlugin = React.createElement(StudioComponents.PluginProvider, {
			Plugin = plugin,
		}, {
			App = React.createElement(App),
		}),
	}))

	plugin.Unloading:Connect(function()
		dockRoot:unmount()
		dock:Destroy()
		button:Destroy()
	end)
end

return PostProcessing
