local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
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
	local isPlaying, setIsPlaying = React.useState(false)
	local textBoxRef = React.useRef(nil :: TextBox?)

	React.useEffect(function()
		local textBox = textBoxRef.current
		if textBox then
			textBox.TextXAlignment = Enum.TextXAlignment.Center
		end
	end, {})

	return React.createElement("Frame", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 10),
		}),

		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -14, 0, 22),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),

			Button = React.createElement(LucideIconButton, {
				Size = UDim2.fromOffset(22, 22),
				Icon = if isPlaying then PAUSE_ICON else PLAY_ICON,
				OnActivated = function()
					setIsPlaying(not isPlaying)
				end,
				LayoutOrder = 1,
				Disabled = props.Disabled,
			}),

			PaddingFrame1 = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 2, 1, 0),
				LayoutOrder = 2,
			}),

			Time = React.createElement(StudioProperties.NumberBox, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(24, 0),
				Size = UDim2.fromOffset(28, 22),

				Value = 123,
				Step = 0,

				HighlightOnFocus = true,
				HighlightMode = "TextboxFocused",

				LayoutOrder = 3,
				Disabled = props.Disabled,
				ref = textBoxRef,
			}),

			PaddingFrame2 = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 4, 1, 0),
				LayoutOrder = 4,
			}),

			Slider = React.createElement(StudioComponents.Slider, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(1, -56, 1, 0),
				Min = 0,
				Max = 1,
				Value = 0,
				Background = false,
				Border = false,
				LayoutOrder = 5,
				Disabled = props.Disabled,
			}),
		}),
	})
end

return PlaybackBar
