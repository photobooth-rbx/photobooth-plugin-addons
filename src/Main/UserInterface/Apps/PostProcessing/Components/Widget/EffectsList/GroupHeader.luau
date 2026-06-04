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
	AnchorPoint: Vector2?,
	Position: UDim2?,

	GroupName: string,
	ForceExpanded: boolean?,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,

	OnMoveActivated: (number) -> ()?,
	OnTrashActivated: () -> ()?,

	children: React.ReactNode?,
}

local function PropertyGroup(props: Props)
	local theme = StudioComponents.useTheme()
	local isHovered, setIsHovered = React.useState(false)

	local isExpanded, setIsExpanded = React.useState(true)
	if props.ForceExpanded ~= nil then
		isExpanded = props.ForceExpanded
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Header = React.createElement("Frame", {
			BackgroundColor3 = if isHovered
				then theme:GetColor(Enum.StudioStyleGuideColor.InputFieldBackground)
				else theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = 1,

			[React.Event.MouseEnter] = function()
				setIsHovered(true)
			end,
			[React.Event.MouseLeave] = function()
				setIsHovered(false)
			end,
		}, {
			Button = props.children
				and React.createElement("Frame", {
					Active = false,
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 22, 1, 0),

					[React.Event.InputBegan] = function(_, input: InputObject)
						if props.ForceExpanded == nil and input.UserInputType == Enum.UserInputType.MouseButton1 then
							setIsExpanded(not isExpanded)
						end
					end,
				}, {
					Icon = React.createElement("ImageLabel", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromOffset(16, 16),
						Image = "rbxassetid://116456051784448",
						ImageRectSize = Vector2.new(16, 16),
						ImageRectOffset = if isExpanded then Vector2.new(16, 0) else Vector2.new(16, 16),
						ImageColor3 = theme:GetColor(
							Enum.StudioStyleGuideColor.ButtonText,
							if props.Disabled
								then Enum.StudioStyleGuideModifier.Disabled
								else Enum.StudioStyleGuideModifier.Default
						),
					}),
				}),
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(22, 0),
				Size = UDim2.new(1, -22, 1, 0),
				FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					if props.Disabled
						then Enum.StudioStyleGuideModifier.Disabled
						else Enum.StudioStyleGuideModifier.Default
				),
				Text = props.GroupName,
				TextSize = 14,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
			}),

			UpDown = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingRight = UDim.new(0, 6),
				}),
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Right,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				DownButton = React.createElement(StudioComponents.Button, {
					Size = UDim2.fromOffset(16, 16),
					Disabled = props.Disabled,
					LayoutOrder = -1,

					Icon = {
						Image = DOWN_ICON.Url,
						RectSize = DOWN_ICON.ImageRectSize,
						RectOffset = DOWN_ICON.ImageRectOffset,
						Size = Vector2.new(DOWN_ICON.ImageRectSize.X, DOWN_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function()
						if props.OnMoveActivated then
							props.OnMoveActivated(1)
						end
					end,
				}),

				Padding1 = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 6, 1, 0),
					LayoutOrder = -2,
				}),

				UpButton = React.createElement(StudioComponents.Button, {
					Size = UDim2.fromOffset(16, 16),
					Disabled = props.Disabled,
					LayoutOrder = -3,

					Icon = {
						Image = UP_ICON.Url,
						RectSize = UP_ICON.ImageRectSize,
						RectOffset = UP_ICON.ImageRectOffset,
						Size = Vector2.new(UP_ICON.ImageRectSize.X, UP_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function()
						if props.OnMoveActivated then
							props.OnMoveActivated(-1)
						end
					end,
				}),

				Padding2 = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(0, 4, 1, 0),
					LayoutOrder = -4,
				}),

				TrashButton = props.OnTrashActivated and React.createElement(LucideIconButton, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 0, 0.5, 0),
					Size = UDim2.fromOffset(24, 24),
					IconSize = UDim2.fromOffset(14, 14),
					Icon = TRASH_ICON,
					Disabled = props.Disabled,
					LayoutOrder = -5,
					OnActivated = function()
						props.OnTrashActivated()
					end,
				}),
			}),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = isExpanded,
			LayoutOrder = 3,
		}, props.children),
	})
end

return PropertyGroup
