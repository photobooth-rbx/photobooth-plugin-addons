local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local function useProperty<T>(instance: Instance?, property: string, default: T)
	local value, setValue = React.useState(default)

	React.useEffect(function()
		if not instance then
			setValue(default)
			return
		end

		setValue((instance :: any)[property])
		local connection = instance:GetPropertyChangedSignal(property):Connect(function()
			print(property)
			setValue((instance :: any)[property])
		end)

		return function()
			connection:Disconnect()
		end
	end, { instance, property } :: { any })

	return value
end

return useProperty
