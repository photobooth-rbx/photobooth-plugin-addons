local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,

	ObservableState: Controller.ObservableState,
	CaptureRect: Rect,

	LayoutOrder: number?,
	Disabled: boolean?,
}

local function Properties(props: Props, ref: any)
	local observedState = props.ObservableState:use()

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

		Photobooth = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Photobooth",
			Disabled = props.Disabled,
			LayoutOrder = 1,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			AlphaBleed = React.createElement(StudioProperties.Boolean, {
				FieldName = "Alpha Bleed",

				Value = observedState.AlphaBleed,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.AlphaBleed = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			CaptureType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Capture Type",

				List = { "NoSkybox", "Unmodified" },
				Value = observedState.CaptureType,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.CaptureType = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),
		}),

		Camera = React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Camera",
			Disabled = props.Disabled,
			LayoutOrder = 2,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			IsFullScreen = React.createElement(StudioProperties.Boolean, {
				FieldName = "Fullscreen",

				Value = observedState.IsFullScreen,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.IsFullScreen = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			CaptureSize = React.createElement(StudioProperties.Vector2, {
				FieldName = "Capture Size",

				Value = if observedState.IsFullScreen
					then Vector2.new(props.CaptureRect.Width, props.CaptureRect.Height)
					else observedState.CaptureSize,
				OnValueSubmitted = function(newValue)
					if not observedState.IsFullScreen then
						props.ObservableState:update()(function(state)
							state.CaptureSize = newValue
							return state
						end)
					end
				end,

				Disabled = if observedState.IsFullScreen then true else props.Disabled,
				LayoutOrder = 2,
			}),

			FitType = React.createElement(StudioProperties.Dropdown, {
				FieldName = "Fit Type",

				List = { "Orbital", "Point Cloud", "Free" },
				Value = observedState.FitType,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.FitType = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			FitTypeSettings = observedState.FitType ~= "Free" and React.createElement(React.Fragment, nil, {
				TryUseMeshVertices = observedState.FitType == "Point Cloud"
					and React.createElement(StudioProperties.Boolean, {
						FieldName = "Use Mesh Vertices",

						Value = observedState.TryUseMeshVertices,
						OnValueSubmitted = function(newValue)
							props.ObservableState:update()(function(state)
								state.TryUseMeshVertices = newValue
								return state
							end)
						end,

						Disabled = props.Disabled,
						LayoutOrder = 4,
					}),

				DistanceScale = React.createElement(StudioProperties.Number, {
					FieldName = "Distance Scale",

					Min = 0,
					Value = observedState.DistanceScale,
					OnValueSubmitted = function(newValue)
						props.ObservableState:update()(function(state)
							state.DistanceScale = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 5,
				}),
			}),

			IsCameraAngleSynced = React.createElement(StudioProperties.Boolean, {
				FieldName = "Sync Angle",

				Value = observedState.IsCameraAngleSynced,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.IsCameraAngleSynced = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 6,
			}),
		}),

		Padding = observedState.FitType ~= "Free" and React.createElement(StudioProperties.PropertyGroup, {
			GroupName = "Padding",
			Disabled = props.Disabled,
			LayoutOrder = 3,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Visible = React.createElement(StudioProperties.Boolean, {
				FieldName = "Visible",

				Value = observedState.PaddingVisible,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.PaddingVisible = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 1,
			}),

			Uniform = React.createElement(StudioProperties.Boolean, {
				FieldName = "Uniform",

				Value = observedState.PaddingUniform,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.PaddingUniform = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 2,
			}),

			UniformAmount = observedState.PaddingUniform and React.createElement(StudioProperties.Number, {
				FieldName = "Uniform Padding",

				Step = 1,
				Min = 0,

				Value = observedState.Padding,
				OnValueSubmitted = function(newValue)
					props.ObservableState:update()(function(state)
						state.Padding = newValue
						return state
					end)
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
			}),

			NonUniformAmounts = not observedState.PaddingUniform and React.createElement(React.Fragment, {}, {
				Top = React.createElement(StudioProperties.Number, {
					FieldName = "Top Padding",

					Step = 1,
					Min = 0,

					Value = observedState.PaddingTop,
					OnValueSubmitted = function(newValue)
						props.ObservableState:update()(function(state)
							state.PaddingTop = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 4,
				}),
				Right = React.createElement(StudioProperties.Number, {
					FieldName = "Right Padding",

					Step = 1,
					Min = 0,

					Value = observedState.PaddingRight,
					OnValueSubmitted = function(newValue)
						props.ObservableState:update()(function(state)
							state.PaddingRight = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 5,
				}),
				Bottom = React.createElement(StudioProperties.Number, {
					FieldName = "Bottom Padding",

					Step = 1,
					Min = 0,

					Value = observedState.PaddingBottom,
					OnValueSubmitted = function(newValue)
						props.ObservableState:update()(function(state)
							state.PaddingBottom = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 6,
				}),
				Left = React.createElement(StudioProperties.Number, {
					FieldName = "Left Padding",

					Step = 1,
					Min = 0,

					Value = observedState.PaddingLeft,
					OnValueSubmitted = function(newValue)
						props.ObservableState:update()(function(state)
							state.PaddingLeft = newValue
							return state
						end)
					end,

					Disabled = props.Disabled,
					LayoutOrder = 7,
				}),
			}),
		}),
	})
end

return React.forwardRef(Properties)
