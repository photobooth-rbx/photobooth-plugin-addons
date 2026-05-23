local RunService = game:GetService("RunService") :: RunService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local PLAY_ICON = assert(Lucide.GetAsset("play", 16))
local PAUSE_ICON = assert(Lucide.GetAsset("pause", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	AnimationTrack: AnimationTrack?,

	Disabled: boolean?,
}

local function clampValue(value: number, step: number, minValue: number, maxValue: number)
	if step > 0 then
		-- this function attempts to robustly decimal nudge to avoid
		-- floating point errors when it comes to step flooring
		local nudge = math.abs(value) * 1e-14
		local stepped = math.floor((value / step) + (nudge / step) + 1e-14) * step
		value = math.round(stepped * 10e10) / 10e10
	end
	return math.clamp(value, minValue, maxValue)
end

local function useTrackControl(track: AnimationTrack?)
	local length = Hooks.useProperty(track, "Length", 0)
	local speed, setRawSpeed = React.useState(track and track.Speed or 0)
	local position, setRawPosition = React.useState(track and track.TimePosition or 0)

	local setSpeed = React.useCallback(function(newSpeed: number)
		if track then
			track:AdjustSpeed(newSpeed)
			setRawSpeed(newSpeed)
		end
	end, { track })

	local setPosition = React.useCallback(function(newPosition: number)
		if track then
			track.TimePosition = newPosition
			setRawPosition(newPosition)
		end
	end, { track })

	React.useEffect(function()
		local trove = Trove.new()

		if track and speed > 0 then
			trove:Add(RunService.PreRender:Connect(function(dt)
				setPosition((track.TimePosition + (dt * track.Speed)) % track.Length)
			end))
		end

		return function()
			trove:Destroy()
		end
	end, { track, speed, setPosition } :: { any })

	return {
		length = length,
		speed = speed,
		setSpeed = setSpeed,
		position = position,
		setPosition = setPosition,
	}
end

local function PlaybackBar(props: Props)
	local theme = StudioComponents.useTheme()
	local track = useTrackControl(props.AnimationTrack)
	local textBoxRef = React.useRef(nil :: TextBox?)

	React.useEffect(function()
		local textBox = textBoxRef.current
		if textBox then
			textBox.TextXAlignment = Enum.TextXAlignment.Right
		end
	end, {})

	return React.createElement("Frame", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,

		Visible = not not props.AnimationTrack,
	}, {
		UICorner = React.createElement("UICorner", {
			CornerRadius = UDim.new(0, 6),
		}),

		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -14, 0, 22),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),

			Button = React.createElement(LucideIconButton, {
				Size = UDim2.fromOffset(22, 22),
				Icon = if track.speed > 0 then PAUSE_ICON else PLAY_ICON,
				OnActivated = function()
					local newSpeed = if track.speed > 0 then 0 else 1
					track.setSpeed(newSpeed)
				end,
				LayoutOrder = 1,
				Disabled = props.Disabled,
			}),

			PaddingFrame1 = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 2, 1, 0),
				LayoutOrder = 2,
			}),

			Time = React.createElement(StudioProperties.NumberBox, {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(24, 0),
				Size = UDim2.fromOffset(28, 22),

				Value = clampValue(track.position, 0.01, 0, track.length),
				Min = 0,
				Max = track.length,
				Step = 0.01,
				StepButtonsDisabled = true,

				OnValueSubmitted = function(newValue)
					track.setPosition(newValue)
					track.setSpeed(0)
				end,

				HighlightOnFocus = true,
				HighlightMode = "TextboxFocused",

				LayoutOrder = 3,
				Disabled = props.Disabled,
				ref = textBoxRef,
			}),

			PaddingFrame2 = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 4, 1, 0),
				LayoutOrder = 4,
			}),

			Slider = React.createElement(StudioComponents.Slider, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(1, -56, 1, 0),
				Min = 0,
				Max = track.length,
				Value = track.position,
				OnChanged = function(newValue)
					track.setPosition(newValue)
					track.setSpeed(0)
				end,
				Background = false,
				Border = false,
				LayoutOrder = 5,
				Disabled = props.Disabled,
			}),
		}),
	})
end

return PlaybackBar
