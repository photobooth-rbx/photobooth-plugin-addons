local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PhotoboothBindings = require(pluginRoot.Packages.PhotoboothBindings)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local EffectsList = require(script.EffectsList)
local PresetsList = require(script.PresetsList)
local ImageViewer = require(script.ImageViewer)

local ACTION_BAR_HEIGHT = 38

local IMAGE_ICON = assert(Lucide.GetAsset("image", 16))
local IMAGES_ICON = assert(Lucide.GetAsset("images", 16))
local RIGHT_ICON = assert(Lucide.GetAsset("chevron-right", 16))
local LEFT_ICON = assert(Lucide.GetAsset("chevron-left", 16))

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

local function useSelectedEditImages()
	local selected = Hooks.useSelection()
	local index, setIndex = React.useState(1)

	local filtered, names = React.useMemo(function()
		local editImages = {}
		local nameByEditImage = {}
		for _, instance in selected do
			if instance:IsA("MeshPart") then
				local editImage = instance.TextureContent.Object
				if editImage and editImage:IsA("EditableImage") then
					table.insert(editImages, editImage)
					nameByEditImage[editImage] = instance.Name
				end
			end
		end
		return editImages, nameByEditImage
	end, { selected })

	React.useEffect(function()
		setIndex(1)
	end, { selected })

	return {
		images = filtered,
		nameByImage = names,
		count = #filtered,
		index = index,
		setIndex = setIndex,
	}
end

local function getImageButtonColor(theme: StudioTheme, modifier: Enum.StudioStyleGuideModifier)
	if modifier == Enum.StudioStyleGuideModifier.Selected then
		return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Pressed)
	elseif modifier == Enum.StudioStyleGuideModifier.Hover then
		return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Hover)
	end
	return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled)
end

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()

	local controller = useController()
	local selected = useSelectedEditImages()

	local layers = controller:useComposited()
	local selectedTab, setSelectedTab = React.useState("Effects")
	local isApplying, setIsApplying = React.useState(false)
	local loadingLayer, setLoadingLayer = React.useState(nil :: Controller.RenderLayer?)
	local disabled = isApplying or not not props.Disabled

	React.useEffect(function()
		if not isApplying then
			local editImage = selected.images[selected.index]
			if editImage then
				task.spawn(function()
					setLoadingLayer(Controller.loadingLayer(editImage))
					controller:loadImageAsync(editImage)
					setLoadingLayer(nil :: any)
				end)
			else
				controller:unloadImage()
				setLoadingLayer(nil :: any)
			end
		end
	end, { selected.images, selected.index, isApplying } :: { any })

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
					Size = UDim2.new(0, 280, 1, 0),
				}, {
					Tabs = React.createElement(StudioComponents.TabContainer, {
						SelectedTab = selectedTab,
						OnTabSelected = setSelectedTab,
					}, {
						Effects = {
							LayoutOrder = 1,
							Content = React.createElement(EffectsList, {
								Size = UDim2.fromScale(1, 1),
								Controller = controller,
								Disabled = disabled,
							}),
						},

						Presets = {
							LayoutOrder = 2,
							Content = React.createElement(PresetsList, {
								Size = UDim2.fromScale(1, 1),
								Controller = controller,
								Disabled = disabled,
							}),
						},
					}),
				}),

				Left = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -280, 1, 0),
				}, {
					ImageViewer = React.createElement(ImageViewer, {
						Size = UDim2.fromScale(1, 1),
						Title = "Image",
						IsLoading = not not loadingLayer,
						Layers = if loadingLayer then { loadingLayer } else layers,
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
					Size = UDim2.new(0, 280, 1, 0),
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

					Compose = React.createElement(StudioComponents.MainButton, {
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

							local editImage = controller.editImage
							if editImage then
								local composed = controller:composeImageAsync(editImage)
								local meshPart = PhotoboothBindings.getMeshPart()
								meshPart.Name = selected.nameByImage[editImage] or "Composition"
								meshPart.TextureContent = Content.fromObject(composed)
								meshPart.Parent = game:GetService("StarterGui")
							end

							setIsApplying(false)
						end,
					}),

					ComposeAll = React.createElement(StudioComponents.Button, {
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

							local folder = Instance.new("Folder")
							for i, editImage in selected.images do
								local composed = controller:composeImageAsync(editImage)
								local meshPart = PhotoboothBindings.getMeshPart()
								meshPart.Name = selected.nameByImage[editImage] or `{i}_Composition`
								meshPart.TextureContent = Content.fromObject(composed)
								meshPart.Parent = folder
							end

							folder.Name = "Composed"
							folder.Parent = game:GetService("StarterGui")

							game:GetService("Selection"):Set({ folder })

							setIsApplying(false)
						end,
					}),
				}),

				ImageIndexer = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(16 * 6, 16),
				}, {
					LeftButton = React.createElement(LucideIconButton, {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.fromOffset(LEFT_ICON.ImageRectSize.X, LEFT_ICON.ImageRectSize.Y),
						Disabled = props.Disabled,
						Icon = LEFT_ICON,
						GetImageColor = function(modifier)
							return getImageButtonColor(theme, modifier)
						end,
						OnActivated = function()
							selected.setIndex(math.max(0, (((selected.index - 1) - 1) % selected.count) + 1))
						end,
					}),

					CountLabel = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -40, 1, 0),

						Text = `{math.min(selected.index, selected.count)} / {selected.count}`,
						TextColor3 = theme:GetColor(
							Enum.StudioStyleGuideColor.MainText,
							Enum.StudioStyleGuideModifier.Disabled
						),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),

					RightButton = React.createElement(LucideIconButton, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, 0),
						Size = UDim2.fromOffset(RIGHT_ICON.ImageRectSize.X, RIGHT_ICON.ImageRectSize.Y),
						Disabled = props.Disabled,
						Icon = RIGHT_ICON,
						GetImageColor = function(modifier)
							return getImageButtonColor(theme, modifier)
						end,
						OnActivated = function()
							selected.setIndex(math.max(0, (((selected.index + 1) - 1) % selected.count) + 1))
						end,
					}),
				}),
			}),
		}),

		Overlay = isApplying and React.createElement("ImageButton", {
			BorderSizePixel = 0,
			BackgroundTransparency = 0.7,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			AutoButtonColor = false,
			Image = "",
		}, {
			Dots = React.createElement(StudioComponents.LoadingDots, {
				Size = UDim2.fromScale(1, 1),
			}),
		}),
	})
end

return Widget
