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
	IsVisible: boolean,
	IsSelected: boolean,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,
}

local function Layer(props: Props)
	local theme = StudioComponents.useTheme()

	return React.createElement("Frame", {
		BackgroundTransparency = if props.IsSelected then 0.9 else 0,
		BackgroundColor3 = if props.IsSelected
			then theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, Enum.StudioStyleGuideModifier.Selected)
			else theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4 + 22 + 4),
			PaddingRight = UDim.new(0, 4),
		}),

		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		Visibility = React.createElement(LucideIconButton, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(22, 22),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = if props.IsVisible then EYE_ICON else EYE_OFF_ICON,
			Disabled = props.Disabled,
			LayoutOrder = 1,

			OnActivated = function()
				-- setIsVisible(not isVisible)
			end,
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
			Text = props.Title,
			TextSize = 14,
			LayoutOrder = 2,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
		}),
	})
end

return Layer
