local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local InnerShadow = require(script.Parent)

type InnerShadowEffect = EffectsRegistry.Effect<InnerShadow.Properties>
export type Props = EffectsRegistry.EffectProps<InnerShadow.Properties>

local function InnerShadowEffect(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Blur = React.createElement(StudioProperties.Number, {
			FieldName = "Blur",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.blur,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.blur = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Spread = React.createElement(StudioProperties.Number, {
			FieldName = "Spread",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.spread,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.spread = newValue
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

return InnerShadowEffect
