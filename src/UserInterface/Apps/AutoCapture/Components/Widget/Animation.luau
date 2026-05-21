local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

local PLAY_ICON = assert(Lucide.GetAsset("play", 16))
local PAUSE_ICON = assert(Lucide.GetAsset("pause", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,

	AnimationManager: Controller.AnimationManager?,

	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Animation(props: Props, ref: any)
	local theme = StudioComponents.useTheme()
	local disabled = props.Disabled --or not props.AnimationManager

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

		Animation = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Animation",
			Disabled = props.Disabled,
			LayoutOrder = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			AnimationId = React.createElement(StudioProperties.Number, {
				FieldName = "Animation Id",

				Step = 1,
				Value = 0,
				OnValueSubmitted = function(newValue) end,

				Disabled = disabled,
				LayoutOrder = 1,
			}),

			PlaybackBar = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 22),
				LayoutOrder = 2,
			}, {
				Container = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -4, 1, 0),
				}, {
					Button = React.createElement(LucideIconButton, {
						Size = UDim2.fromOffset(22, 22),
						Icon = PLAY_ICON,
						Disabled = disabled,
					}),

					Time = React.createElement(StudioProperties.NumberBox, {
						BackgroundTransparency = 1,
						Position = UDim2.fromOffset(24, 0),
						Size = UDim2.fromOffset(40, 21),

						Value = 123,
						Step = 0,
						HighlightMode = "TextboxFocused",

						Disabled = disabled,
					}),

					Slider = React.createElement(StudioComponents.Slider, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.fromScale(1, 0.5),
						Size = UDim2.new(1, -66, 1, -4),
						Min = 0,
						Max = 1,
						Value = 0,
						Background = false,
						Border = false,
						Disabled = disabled,
					}),
				}),
			}),
		}),
	})
end

return React.forwardRef(Animation)
