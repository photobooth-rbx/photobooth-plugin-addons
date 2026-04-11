local SelectionService = game:GetService("Selection") :: Selection

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local Future = require(pluginRoot.Packages.Future)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local uiRoot = script:FindFirstAncestor("UserInterface")
local InstanceList = require(uiRoot.Components.InstanceList)
local Hooks = require(uiRoot.Hooks)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local ImageViewer = require(script.ImageViewer)
local Properties = require(script.Properties)

local BUTTONS_HEIGHT = 38

local IMAGE_ICON = assert(Lucide.GetAsset("image", 16))
local IMAGES_ICON = assert(Lucide.GetAsset("images", 16))

export type Props = {
	ObservableRenderState: Controller.ObservableRenderState,
	ObservableNonRenderState: Controller.ObservableNonRenderState,

	Disabled: boolean?,
}

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()
	local isApplying, setIsApplying = React.useState(false)
	local forceRender = Hooks.useUpdate()

	local watchingMeshPartSetRef = React.useRef({})
	local applyingTroveRef = React.useRef(Trove.new())
	local controllerRef = React.useRef(Controller.new(props.ObservableRenderState, props.ObservableNonRenderState))

	local layers = controllerRef.current:useLayers()
	local title, setTitle = React.useState("")

	local propertiesRef = React.useRef(nil)
	local propertiesAbsSize = Hooks.useRefProperty(propertiesRef, "AbsoluteSize", Vector2.zero)

	local listRef = React.useRef({} :: InstanceList.List<MeshPart>)
	local nList = #listRef.current

	React.useEffect(function()
		return function()
			applyingTroveRef.current:Destroy()
		end
	end, {})

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

				List = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),

					Properties = React.createElement(Properties, {
						ObservableRenderState = props.ObservableRenderState,
						ObservableNonRenderState = props.ObservableNonRenderState,
						Disabled = isApplying or not not props.Disabled,
						LayoutOrder = 1,
						ref = propertiesRef,
					}),

					InstanceList = React.createElement(InstanceList, {
						Size = UDim2.new(1, 0, 1, -propertiesAbsSize.Y),

						ForceRender = forceRender,
						ListRef = listRef,

						OnListElementAdded = function(element)
							watchingMeshPartSetRef.current[element.instance :: MeshPart] = true
						end,
						OnListElementSelected = function(element)
							if element then
								local meshPart = element.instance :: MeshPart
								local editImage = meshPart.TextureContent and meshPart.TextureContent.Object

								if editImage and editImage:IsA("EditableImage") then
									setTitle(meshPart.Name)
									task.spawn(function()
										controllerRef.current:loadAsync(editImage)
									end)
								end
							end

							if not element then
								controllerRef.current:clear()
							end
						end,
						OnListElementRemoved = function(element)
							watchingMeshPartSetRef.current[element.instance :: MeshPart] = nil
						end,

						--OverrideClassName = "ImageButton",
						FilterSelection = function(instance)
							local textureContent = instance:IsA("MeshPart") and instance.TextureContent or nil
							local isEditableImage = textureContent
								and textureContent.Object
								and textureContent.Object:IsA("EditableImage")
							return if isEditableImage then instance else nil
						end,

						Disabled = isApplying or not not props.Disabled,
						LayoutOrder = 2,
					}),
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
					Disabled = isApplying or nList == 0 or not not props.Disabled,
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

						local finishedFuture = Future.new()

						applyingTroveRef.current:Add(function()
							if not finishedFuture:isCompleted() then
								finishedFuture:complete()
							end
						end)

						applyingTroveRef.current:Add(task.spawn(function()
							local newSelection: { Instance } = {}
							for meshPart, _ in watchingMeshPartSetRef.current do
								local composited = controllerRef.current:composeAsync()

								local archivable = meshPart.Archivable
								meshPart.Archivable = true
								local meshCopy = meshPart:Clone()
								meshPart.Archivable = archivable
								meshCopy:ClearAllChildren()

								meshCopy.TextureContent = Content.fromObject(composited)
								meshCopy.Name = meshPart.Name .. "_PostProcessed"
								meshCopy.Parent = meshPart

								table.insert(newSelection, meshCopy)
								break
							end

							if #newSelection > 0 then
								SelectionService:Set(newSelection)
							end

							finishedFuture:complete()
						end))

						finishedFuture:expect()

						setIsApplying(false)
					end,
				}),

				ComposeAll = not isApplying and React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					Text = "Compose All",
					Disabled = isApplying or nList == 0 or not not props.Disabled,
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

						local finishedFuture = Future.new()
						local tmpController =
							Controller.new(props.ObservableRenderState, props.ObservableNonRenderState)

						applyingTroveRef.current:Add(function()
							if not finishedFuture:isCompleted() then
								finishedFuture:complete()
							end
						end)

						applyingTroveRef.current:Add(task.spawn(function()
							local newSelection: { Instance } = {}
							for meshPart, _ in watchingMeshPartSetRef.current do
								local editImage = meshPart.TextureContent and meshPart.TextureContent.Object
								if editImage and editImage:IsA("EditableImage") then
									tmpController:loadAsync(editImage)
									local composited = tmpController:composeAsync()

									local archivable = meshPart.Archivable
									meshPart.Archivable = true
									local meshCopy = meshPart:Clone()
									meshPart.Archivable = archivable
									meshCopy:ClearAllChildren()

									meshCopy.TextureContent = Content.fromObject(composited)
									meshCopy.Name = meshPart.Name .. "_PostProcessed"
									meshCopy.Parent = meshPart

									table.insert(newSelection, meshCopy)
								end
							end

							if #newSelection > 0 then
								SelectionService:Set(newSelection)
							end

							finishedFuture:complete()
						end))

						finishedFuture:expect()
						tmpController:Destroy()

						setIsApplying(false)
					end,
				}),

				Cancel = isApplying and React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					Text = "Cancel",
					Disabled = props.Disabled,

					OnActivated = function()
						applyingTroveRef.current:Clean()
					end,
				}),
			}),
		}),

		Left = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -240, 1, 0),
		}, {
			ImageViewer = React.createElement(ImageViewer, {
				Size = UDim2.fromScale(1, 1),
				Title = title,
				Layers = layers,
			}),
		}),
	})
end

return Widget
