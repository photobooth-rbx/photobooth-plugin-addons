local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

export type Props = {
	Layer: Controller.DropShadowLayer,
	UpdateLayer: ((Controller.DropShadowLayer) -> Controller.DropShadowLayer?) -> (),
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function DropShadowLayer(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",

			Min = 0,
			Max = 1,

			Value = props.Layer.properties.transparency,
			OnValueSubmitted = function(newValue)
				props.UpdateLayer(function(layer)
					layer.properties.transparency = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Color",

			Value = props.Layer.properties.color,
			OnValueSubmitted = function(newValue)
				props.UpdateLayer(function(layer)
					layer.properties.color = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Offset = React.createElement(StudioProperties.Vector2, {
			FieldName = "Offset",

			Value = props.Layer.properties.offset,
			OnValueSubmitted = function(newValue)
				props.UpdateLayer(function(layer)
					layer.properties.offset = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),

		Spread = React.createElement(StudioProperties.Number, {
			FieldName = "Spread",

			Step = 1,
			Min = 0,

			Value = props.Layer.properties.spread,
			OnValueSubmitted = function(newValue)
				props.UpdateLayer(function(layer)
					layer.properties.spread = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 4,
		}),

		Blur = React.createElement(StudioProperties.Number, {
			FieldName = "Blur",

			Step = 1,
			Min = 0,

			Value = props.Layer.properties.blur,
			OnValueSubmitted = function(newValue)
				props.UpdateLayer(function(layer)
					layer.properties.blur = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 5,
		}),
	})
end

return DropShadowLayer
