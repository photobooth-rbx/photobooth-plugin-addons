local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local GroupHeader = require(script.Parent.Parent.GroupHeader)

export type Props = {
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function StrokeLayer(props: Props)
	return React.createElement(GroupHeader, {
		GroupName = "Stroke",
		LayoutOrder = props.LayoutOrder,
		Disabled = props.Disabled,
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

			Value = 1,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Softness = React.createElement(StudioProperties.Number, {
			FieldName = "Softness",

			Step = 1,
			Min = 0,

			Value = 0,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",

			Min = 0,
			Max = 1,

			Value = 0,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Color",

			Value = Color3.new(0, 0, 0),
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 4,
		}),
	})
end

return StrokeLayer
