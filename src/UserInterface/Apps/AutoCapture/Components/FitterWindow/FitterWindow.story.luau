local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local FitterWindow = require(script.Parent)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local function Component(props: { Size: UDim2 })
	local padding = 5

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
	}, {
		Core = React.createElement(FitterWindow, {
			Resolution = Vector2.new(256, 256),
			IsFullScreen = false,

			PaddingTop = padding,
			PaddingBottom = padding,
			PaddingLeft = padding,
			PaddingRight = padding,
			PaddingVisible = true,

			OnCaptureRectChanged = function(_rect) end,
			OnPaddedRectChanged = function(_rect) end,

			Disabled = false,
		}),
	})
end

return {
	react = React,
	reactRoblox = ReactRoblox,
	story = CreateStory.theme(function()
		return React.createElement(Component, {
			Size = UDim2.fromScale(1, 1),
		})
	end),
}
