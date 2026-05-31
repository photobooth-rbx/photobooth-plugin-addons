local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local OutlineLayer = require(script.Layers.OutlineLayer)
local DropShadowLayer = require(script.Layers.DropShadowLayer)

local PLUS_ICON = assert(Lucide.GetAsset("plus", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Effects(props: Props)
	local theme = StudioComponents.useTheme()

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Scroll = React.createElement(StudioProperties.VerticalScroll, {
			Size = UDim2.fromScale(1, 1),
			GradientHeight = 22,
			ScrollInset = UDim.new(0, -2),
			ScrollBarTransparency = 0.7,
			ScrollBarFades = true,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),

			Layers = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				Outline = React.createElement(OutlineLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 1,
				}),

				DropShadow = React.createElement(DropShadowLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 2,
				}),
			}),

			AddNewButton = false and React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, 38),
				ClipsDescendants = true,
				LayoutOrder = 2,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 3),
					PaddingRight = UDim.new(0, 3),
					PaddingTop = UDim.new(0, 3),
					PaddingBottom = UDim.new(0, 4),
				}),

				ComposeAll = React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					Text = "Add",
					Disabled = props.Disabled,

					Icon = {
						Image = PLUS_ICON.Url,
						RectSize = PLUS_ICON.ImageRectSize,
						RectOffset = PLUS_ICON.ImageRectOffset,
						Size = Vector2.new(PLUS_ICON.ImageRectSize.X, PLUS_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function() end,
				}),
			}),
		}),
	})
end

return Effects
