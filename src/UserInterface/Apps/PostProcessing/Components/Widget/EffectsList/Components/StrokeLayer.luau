local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

export type Props = {
	Effect: Controller.StrokeEffect,
	UpdateEffect: ((Controller.StrokeEffect) -> Controller.StrokeEffect?) -> (),
	Disabled: boolean?,
}

local function StrokeEffect(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Thickness = React.createElement(StudioProperties.Number, {
			FieldName = "Thickness",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.thickness,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.thickness = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Softness = React.createElement(StudioProperties.Number, {
			FieldName = "Softness",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.softness,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.softness = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",

			Min = 0,
			Max = 1,

			Value = props.Effect.properties.transparency,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.transparency = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Color",

			Value = props.Effect.properties.color,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.color = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 4,
		}),
	})
end

return StrokeEffect
