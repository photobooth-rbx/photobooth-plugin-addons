local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local PLAY_ICON = assert(Lucide.GetAsset("play", 16))
local PAUSE_ICON = assert(Lucide.GetAsset("pause", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Disabled: boolean?,
}

local function PlaybackBar(props: Props)
	local theme = StudioComponents.useTheme()

	return React.createElement("Frame", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder),
		BorderMode = Enum.BorderMode.Inset,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
	}, {
		Button = React.createElement(LucideIconButton, {
			Size = UDim2.fromOffset(22, 22),
			Icon = PLAY_ICON,
			Disabled = props.Disabled,
		}),

		Slider = React.createElement(StudioComponents.Slider, {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.new(1, -22, 1, 0),
			Min = 0,
			Max = 1,
			Value = 0,
			Disabled = props.Disabled,
		}),
	})
end

return PlaybackBar
