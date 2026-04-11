local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local observableRenderState = Controller.createRenderState()
local observableNonRenderState = Controller.createNonRenderState()

local Widget = require(script.Parent)

local function Component(props: { Size: UDim2 })
	local theme = StudioComponents.useTheme()
	local disabled, setDisabled = React.useState(false)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Core = React.createElement(Widget, {
			ObservableRenderState = observableRenderState,
			ObservableNonRenderState = observableNonRenderState,
			Disabled = disabled,
		}),
	})
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = CreateStory.theme(function()
		return React.createElement(Component, {
			Size = UDim2.fromOffset(750, 450),
		})
	end),
}
