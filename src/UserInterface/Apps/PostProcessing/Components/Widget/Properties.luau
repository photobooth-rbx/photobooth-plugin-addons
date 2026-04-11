local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,

	ObservableRenderState: Controller.ObservableRenderState,
	ObservableNonRenderState: Controller.ObservableNonRenderState,

	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Properties(props: Props, ref: any)
	local observedRenderState = props.ObservableRenderState:use()
	local observedNonRenderState = props.ObservableNonRenderState:use()

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		ref = ref,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Stroke = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Stroke",
			Disabled = props.Disabled,
			LayoutOrder = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Thickness = React.createElement(StudioProperties.Number, {
				FieldName = "Thickness",

				Step = 1,
				Min = 0,

				Value = observedRenderState.StrokeThickness,
				OnValueSubmitted = function(newValue)
					props.ObservableRenderState:update()(function(state)
						state.StrokeThickness = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			Softness = React.createElement(StudioProperties.Number, {
				FieldName = "Softness",

				Step = 1,
				Min = 0,

				Value = observedRenderState.StrokeSoftness,
				OnValueSubmitted = function(newValue)
					props.ObservableRenderState:update()(function(state)
						state.StrokeSoftness = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			Transparency = React.createElement(StudioProperties.Number, {
				FieldName = "Transparency",

				Min = 0,
				Max = 1,

				Value = observedNonRenderState.StrokeTransparency,
				OnValueSubmitted = function(newValue)
					props.ObservableNonRenderState:update()(function(state)
						state.StrokeTransparency = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			Color = React.createElement(StudioProperties.Color3, {
				FieldName = "Color",

				Value = observedNonRenderState.StrokeColor,
				OnValueSubmitted = function(newValue)
					props.ObservableNonRenderState:update()(function(state)
						state.StrokeColor = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 4,
			}),
		}),

		DropShadow = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Drop Shadow",
			Disabled = props.Disabled,
			LayoutOrder = 2,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Transparency = React.createElement(StudioProperties.Number, {
				FieldName = "Transparency",

				Min = 0,
				Max = 1,

				Value = observedNonRenderState.DropShadowTransparency,
				OnValueSubmitted = function(newValue)
					props.ObservableNonRenderState:update()(function(state)
						state.DropShadowTransparency = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			Color = React.createElement(StudioProperties.Color3, {
				FieldName = "Color",

				Value = observedNonRenderState.DropShadowColor,
				OnValueSubmitted = function(newValue)
					props.ObservableNonRenderState:update()(function(state)
						state.DropShadowColor = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			Offset = React.createElement(StudioProperties.Vector2, {
				FieldName = "Offset",

				Value = observedRenderState.DropShadowOffset,
				OnValueSubmitted = function(newValue)
					props.ObservableRenderState:update()(function(state)
						state.DropShadowOffset = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			Spread = React.createElement(StudioProperties.Number, {
				FieldName = "Spread",

				Step = 1,
				Min = 0,
				Value = observedRenderState.DropShadowSpread,
				OnValueSubmitted = function(newValue)
					props.ObservableRenderState:update()(function(state)
						state.DropShadowSpread = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 4,
			}),

			Blur = React.createElement(StudioProperties.Number, {
				FieldName = "Blur",

				Step = 1,
				Min = 0,
				Value = observedRenderState.DropShadowBlur,
				OnValueSubmitted = function(newValue)
					props.ObservableRenderState:update()(function(state)
						state.DropShadowBlur = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 5,
			}),
		}),
	})
end

return React.forwardRef(Properties)
