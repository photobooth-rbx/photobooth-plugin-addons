local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local function useInstanceAttribute<T>(instance: Instance, attribute: string, default: T)
	local value, setValue = React.useState(default)

	React.useEffect(function()
		setValue((instance:GetAttribute(attribute) :: T?) or default)
		local connection = instance:GetAttributeChangedSignal(attribute):Connect(function()
			setValue((instance:GetAttribute(attribute) :: T?) or default)
		end)

		return function()
			connection:Disconnect()
		end
	end, { instance, attribute } :: { any })

	return value
end

return useInstanceAttribute
