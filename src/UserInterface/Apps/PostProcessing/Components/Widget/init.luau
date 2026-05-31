local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local Effects = require(script.Effects)
local ImageViewer = require(script.ImageViewer)
local EffectDialog = require(script.EffectDialog)

local ACTION_BAR_HEIGHT = 38

local IMAGE_ICON = assert(Lucide.GetAsset("image", 16))
local IMAGES_ICON = assert(Lucide.GetAsset("images", 16))
local PLUS_ICON = assert(Lucide.GetAsset("plus", 16))

export type Props = {
	Disabled: boolean?,
}

local function useController()
	local controller = Hooks.useConstant(function()
		return Controller.new()
	end)

	React.useEffect(function()
		return function()
			controller:Destroy()
		end
	end, {})

	return controller
end

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()
	local controller = useController()

	local isApplying, setIsApplying = React.useState(false)
	local isDialogOpen, setIsDialogOpen = React.useState(false)
	local disabled = isApplying or isDialogOpen or not not props.Disabled

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = -1, -- Fixes dropdown issues
	}, {
		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = -1,
		}, {
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -ACTION_BAR_HEIGHT),
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
						Size = UDim2.new(1, 0, 1, -28),
					}, {
						Dots = isApplying and React.createElement(StudioComponents.LoadingDots, {
							Size = UDim2.fromScale(1, 1),
							ZIndex = 2,
						}),

						Effects = React.createElement(Effects, {
							Size = UDim2.fromScale(1, 1),
							Controller = controller,
							Disabled = disabled,
						}),
					}),

					AddNewEffect = React.createElement("Frame", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0, 1),
						Position = UDim2.fromScale(0, 1),
						Size = UDim2.new(1, 0, 0, 28),
						ClipsDescendants = true,
					}, {
						Padding = React.createElement("UIPadding", {
							PaddingLeft = UDim.new(0, 3),
							PaddingRight = UDim.new(0, 3),
							PaddingTop = UDim.new(0, 3),
							PaddingBottom = UDim.new(0, 3),
						}),
						ClipFrame = React.createElement("Frame", {
							BackgroundTransparency = 1,
							Size = UDim2.new(1, 0, 1, 0),
							ClipsDescendants = true,
						}, {
							Button = React.createElement(StudioComponents.Button, {
								LayoutOrder = -2,
								Size = UDim2.new(1, -2, 1, -2),
								AnchorPoint = Vector2.new(0.5, 0.5),
								Position = UDim2.fromScale(0.5, 0.5),
								TextXAlignment = Enum.TextXAlignment.Center,
								Text = "Add Effect",
								Disabled = disabled,

								Icon = {
									Image = PLUS_ICON.Url,
									RectSize = PLUS_ICON.ImageRectSize,
									RectOffset = PLUS_ICON.ImageRectOffset,
									Size = Vector2.new(PLUS_ICON.ImageRectSize.X, PLUS_ICON.ImageRectSize.Y),
									UseThemeColor = true,
								},

								OnActivated = function()
									setIsDialogOpen(true)
								end,
							}),
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
			}),

			ActionBar = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, ACTION_BAR_HEIGHT),

				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			}, {
				ComposeButtons = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.new(0, 240, 1, 0),
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
						Disabled = disabled,
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
						Disabled = disabled,
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
						Disabled = isDialogOpen or not not props.Disabled,

						OnActivated = function() end,
					}),
				}),
			}),
		}),

		Overlay = isDialogOpen and React.createElement("ImageButton", {
			BorderSizePixel = 0,
			BackgroundTransparency = 0.7,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			AutoButtonColor = false,
			Image = "",
		}, {
			Dialog = React.createElement(EffectDialog, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(220, 120),

				Controller = controller,

				OnConfirm = function(name, effectType)
					setIsDialogOpen(false)
					controller:createLayer(effectType, name)
				end,

				OnCancel = function()
					setIsDialogOpen(false)
				end,
			}),
		}),
	})
end

return Widget
