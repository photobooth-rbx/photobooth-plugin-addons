local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Effects = require(script.Effects)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local ImageViewer = require(script.ImageViewer)

local BUTTONS_HEIGHT = 38

local IMAGE_ICON = assert(Lucide.GetAsset("image", 16))
local IMAGES_ICON = assert(Lucide.GetAsset("images", 16))

export type Props = {
	Disabled: boolean?,
}

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()
	local isApplying, setIsApplying = React.useState(false)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = -1, -- Fixes dropdown issues
	}, {
		Right = React.createElement("Frame", {
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 240, 1, 0),
		}, {
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -BUTTONS_HEIGHT),
			}, {
				Dots = isApplying and React.createElement(StudioComponents.LoadingDots, {
					Size = UDim2.fromScale(1, 1),
					ZIndex = 2,
				}),

				Effects = React.createElement(Effects, {
					Size = UDim2.fromScale(1, 1),
					Disabled = props.Disabled,
				}),
			}),

			Buttons = React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, BUTTONS_HEIGHT),
				ClipsDescendants = true,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 3),
					PaddingRight = UDim.new(0, 3),
					PaddingTop = UDim.new(0, 3),
					PaddingBottom = UDim.new(0, 4),
				}),
				UIListLayout = React.createElement("UIListLayout", {
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					HorizontalFlex = Enum.UIFlexAlignment.Fill,
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 4),
				}),

				Compose = not isApplying and React.createElement(StudioComponents.MainButton, {
					Size = UDim2.fromScale(1, 1),
					Text = "Compose",
					Disabled = isApplying or not not props.Disabled,
					LayoutOrder = -1,

					Icon = {
						Image = IMAGE_ICON.Url,
						RectSize = IMAGE_ICON.ImageRectSize,
						RectOffset = IMAGE_ICON.ImageRectOffset,
						Size = Vector2.new(IMAGE_ICON.ImageRectSize.X, IMAGE_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function()
						setIsApplying(true)

						setIsApplying(false)
					end,
				}),

				ComposeAll = not isApplying and React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					Text = "Compose All",
					Disabled = isApplying or not not props.Disabled,
					LayoutOrder = -2,

					Icon = {
						Image = IMAGES_ICON.Url,
						RectSize = IMAGES_ICON.ImageRectSize,
						RectOffset = IMAGES_ICON.ImageRectOffset,
						Size = Vector2.new(IMAGES_ICON.ImageRectSize.X, IMAGES_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function()
						setIsApplying(true)

						setIsApplying(false)
					end,
				}),

				Cancel = isApplying and React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					Text = "Cancel",
					Disabled = props.Disabled,

					OnActivated = function() end,
				}),
			}),
		}),

		Left = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -240, 1, 0),
		}, {
			ImageViewer = React.createElement(ImageViewer, {
				Size = UDim2.fromScale(1, 1),
				Title = "Image",
				Layers = {},
			}),
		}),
	})
end

return Widget
