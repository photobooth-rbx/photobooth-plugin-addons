local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local PlaybackBar = require(script.PlaybackBar)

export type Props = {
	Resolution: Vector2,
	IsFullScreen: boolean,

	PaddingVisible: boolean,
	PaddingLeft: number,
	PaddingRight: number,
	PaddingTop: number,
	PaddingBottom: number,

	OnCaptureRectChanged: (Rect) -> (),
	OnPaddedRectChanged: (Rect) -> (),

	Disabled: boolean?,
}

local function Fitter(props: Props)
	local theme = StudioComponents.useTheme()

	local captureFrameRef = React.useRef(nil)
	local captureFrameAbsPosition = Hooks.useRefProperty(captureFrameRef, "AbsolutePosition", Vector2.zero)
	local captureFrameAbsSize = Hooks.useRefProperty(captureFrameRef, "AbsoluteSize", Vector2.zero)
	local captureRect = Photobooth.rect.fromAbs(captureFrameAbsPosition, captureFrameAbsSize)

	React.useEffect(function()
		props.OnCaptureRectChanged(captureRect)
	end, { captureRect })

	local paddedFrameRef = React.useRef(nil)
	local paddedFrameAbsPosition = Hooks.useRefProperty(paddedFrameRef, "AbsolutePosition", Vector2.zero)
	local paddedFrameAbsSize = Hooks.useRefProperty(paddedFrameRef, "AbsoluteSize", Vector2.zero)
	local paddedRect = Photobooth.rect.fromAbs(paddedFrameAbsPosition, paddedFrameAbsSize)

	React.useEffect(function()
		props.OnPaddedRectChanged(paddedRect)
	end, { paddedRect })

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	}, {
		Focus = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if props.IsFullScreen
				then UDim2.fromScale(1, 1)
				else UDim2.fromOffset(props.Resolution.X, props.Resolution.Y),
		}, {
			UIStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Transparency = 0,
				Color = theme:GetColor(
					Enum.StudioStyleGuideColor.InputFieldBorder,
					Enum.StudioStyleGuideModifier.Selected
				),
				BorderStrokePosition = if props.IsFullScreen
					then Enum.BorderStrokePosition.Inner
					else Enum.BorderStrokePosition.Outer,
				ZIndex = 2,
			}),

			UIStrokeBlinder = React.createElement("UIStroke", {
				Thickness = 100_000,
				Transparency = 0.7,
				Color = Color3.new(0, 0, 0),
			}),

			Padding = React.createElement("CanvasGroup", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				GroupTransparency = 0.7,
				GroupColor3 = Color3.new(0, 0, 0),
				Visible = props.PaddingVisible,
			}, {
				Top = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, props.PaddingTop),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Right = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, props.PaddingRight, 1, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Bottom = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, props.PaddingBottom),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Left = React.createElement("Frame", {
					Size = UDim2.new(0, props.PaddingLeft, 1, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
			}),

			CaptureFrame = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ref = captureFrameRef,
			}),

			PaddedFrame = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(props.PaddingLeft, props.PaddingTop),
				Size = UDim2.new(
					1,
					-(props.PaddingLeft + props.PaddingRight),
					1,
					-(props.PaddingTop + props.PaddingBottom)
				),
				ref = paddedFrameRef,
			}),

			AnimationBar = React.createElement(PlaybackBar, {
				AnchorPoint = Vector2.new(0.5, if props.IsFullScreen then 1 else 0),
				Position = UDim2.new(0.5, 0, 1, if props.IsFullScreen then -10 else 16),
				Size = UDim2.fromOffset(300, 28),
			}),
		}),
	})
end

return Fitter
