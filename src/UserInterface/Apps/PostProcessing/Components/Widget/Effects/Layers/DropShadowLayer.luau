local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local GroupHeader = require(script.Parent.Parent.GroupHeader)

export type Props = {
	TitleName: string,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function DropShadowLayer(props: Props)
	return React.createElement(GroupHeader, {
		GroupName = props.TitleName,
		LayoutOrder = props.LayoutOrder,
		Disabled = props.Disabled,
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

			Value = 0,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Color",

			Value = Color3.new(0, 0, 0),
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Offset = React.createElement(StudioProperties.Vector2, {
			FieldName = "Offset",

			Value = Vector2.zero,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),

		Spread = React.createElement(StudioProperties.Number, {
			FieldName = "Spread",

			Step = 1,
			Min = 0,
			Value = 1,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 4,
		}),

		Blur = React.createElement(StudioProperties.Number, {
			FieldName = "Blur",

			Step = 1,
			Min = 0,
			Value = 1,
			OnValueSubmitted = function(newValue) end,

			Disabled = props.Disabled,
			LayoutOrder = 5,
		}),
	})
end

return DropShadowLayer
