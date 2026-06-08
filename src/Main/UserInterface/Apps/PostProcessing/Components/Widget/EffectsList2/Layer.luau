local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local EYE_ICON = assert(Lucide.GetAsset("eye", 16))
local EYE_OFF_ICON = assert(Lucide.GetAsset("eye-off", 16))

export type Props = {
	Title: string,
	Indent: number,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,
}

local function Layer(props: Props)
	local theme = StudioComponents.useTheme()
	local isVisible, setIsVisible = React.useState(true)
	local isSelected, setIsSelected = React.useState(false)

	return React.createElement("Frame", {
		BackgroundTransparency = if isSelected then 0.9 else 0,
		BackgroundColor3 = if isSelected
			then theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, Enum.StudioStyleGuideModifier.Selected)
			else theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.new(1, 0, 0, 48),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
		}),

		Visibility = React.createElement(LucideIconButton, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(22, 22),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = if isVisible then EYE_ICON else EYE_OFF_ICON,
			Disabled = props.Disabled,
			OnActivated = function()
				setIsVisible(not isVisible)
			end,
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1, -32, 1, 0),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Icon = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(48, 48),
				LayoutOrder = 1,
			}, {
				Label = React.createElement("Frame", {
					BackgroundTransparency = 0.7,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -10, 1, -10),
				}),
			}),

			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -48, 1, 0),
				FontFace = Font.fromName("SourceSansPro"),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
				),
				Text = "Title",
				TextSize = 14,
				LayoutOrder = 2,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 8),
					PaddingRight = UDim.new(0, 4),
				}),
			}),
		}),
	})
end

return Layer
