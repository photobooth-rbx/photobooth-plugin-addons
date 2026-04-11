local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

local Widget = require(script.Parent)

local function Component(props: { Size: UDim2 })
	local theme = StudioComponents.useTheme()
	local disabled, setDisabled = React.useState(false)
	local observableState = Controller.createState()

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Core = React.createElement(Widget, {
			OnCapture = function()
				setDisabled(true)
				task.wait(1)
				setDisabled(false)
			end,
			OnCaptureAll = function()
				setDisabled(true)
				task.wait(1)
				setDisabled(false)
			end,
			OnListElementAdded = function() end,
			OnListElementSelected = function() end,
			OnListElementRemoved = function() end,
			ObservableState = observableState,
			CaptureRect = Rect.new(0, 0, 0, 0),
			Disabled = disabled,
		}),
	})
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = CreateStory.theme(function()
		return React.createElement(Component, {
			Size = UDim2.fromOffset(260, 450),
		})
	end),
}
