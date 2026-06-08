local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local UP_ICON = assert(Lucide.GetAsset("chevron-up", 16))
local DOWN_ICON = assert(Lucide.GetAsset("chevron-down", 16))
local TRASH_ICON = assert(Lucide.GetAsset("trash", 12))

export type Props = {
	Title: string,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,
}

local function Effect(props: Props)
	local theme = StudioComponents.useTheme()
	local isHovered, setIsHovered = React.useState(false)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 36),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	}, {})
end

return Effect
