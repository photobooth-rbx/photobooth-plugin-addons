local Asphalt = require(script.Parent.Asphalt)

local ButtonIcon = {}

local function getIcon(iconName: string)
	local theme = settings().Studio.Theme
	return assert(Asphalt.processed[theme.Name:lower()][iconName] :: string?)
end

function ButtonIcon.listen(button: PluginToolbarButton, iconName: string)
	local function onThemeChanged()
		button.Icon = getIcon(iconName)
	end

	onThemeChanged()
	local connection = settings().Studio.ThemeChanged:Connect(onThemeChanged)

	button.Destroying:Once(function()
		connection:Disconnect()
	end)
end

return ButtonIcon
