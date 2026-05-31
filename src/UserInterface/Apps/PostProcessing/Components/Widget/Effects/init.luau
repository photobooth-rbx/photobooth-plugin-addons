local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local StrokeLayer = require(script.Layers.StrokeLayer)
local DropShadowLayer = require(script.Layers.DropShadowLayer)

local SCROLL_GRADIENT_INSET_HEIGHT = 22

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Effects(props: Props)
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
			GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
			ScrollInset = UDim.new(0, -2),
			ScrollBarTransparency = 0.7,
			ScrollBarFades = true,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
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

				Stroke = React.createElement(StrokeLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 1,
				}),

				DropShadow = React.createElement(DropShadowLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 2,
				}),

				DropShadow2 = React.createElement(DropShadowLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 3,
				}),

				DropShadow3 = React.createElement(DropShadowLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 4,
				}),

				DropShadow4 = React.createElement(DropShadowLayer, {
					Disabled = props.Disabled,
					LayoutOrder = 5,
				}),
			}),

			Padding = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
				LayoutOrder = 2,
			}),
		}),
	})
end

return Effects
