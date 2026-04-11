local HttpService = game:GetService("HttpService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local usePlugin = require(script.Parent.usePlugin)

export type Action = {
	Text: string,
	Icon: string?,
	OnTrigger: () -> ()?,
}

local function usePluginMenu()
	local plugin = assert(usePlugin())
	local uniqueRef = React.useRef(HttpService:GenerateGUID() :: string)
	local unique = uniqueRef.current

	local menu, setMenu = React.useState(nil :: PluginMenu?)
	React.useEffect(function()
		local pluginMenu = plugin:CreatePluginMenu(unique, unique, "")
		setMenu(pluginMenu)

		return function()
			pluginMenu:Destroy()
		end
	end, { plugin })

	local isOpen = React.useRef(false)
	local openMenu = React.useCallback(function(actionInfos: { Action })
		if menu and not isOpen.current then
			isOpen.current = true

			local actions = {}
			for i, actionInfo in actionInfos do
				local action = menu:AddNewAction(`{unique}_{i}`, actionInfo.Text, actionInfo.Icon)
				action.Triggered:Connect(function()
					if actionInfo.OnTrigger then
						actionInfo.OnTrigger()
					end
				end)

				table.insert(actions, action)
			end

			menu:ShowAsync()

			for _, action in actions do
				action:Destroy()
			end

			isOpen.current = false
		end
	end, { menu })

	return openMenu
end

return usePluginMenu
