local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local InstanceList = require(uiRoot.Components.InstanceList)
local Hooks = require(uiRoot.Hooks)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

local Properties = require(script.Properties)

local BUTTONS_HEIGHT = 38

local CAPTURE_ICON = assert(Lucide.GetAsset("camera", 16))
local CAPTURE_ALL_ICON = assert(Lucide.GetAsset("switch-camera", 16))

export type ListElement = InstanceList.ListElement<PVInstance>

export type Props = {
	OnCapture: () -> (),
	OnCaptureAll: () -> (),
	OnListElementAdded: (ListElement) -> (),
	OnListElementSelected: (ListElement?) -> (),
	OnListElementRemoved: (ListElement) -> (),
	ObservableState: Controller.ObservableState,
	AnimationManager: Controller.AnimationManager?,
	CaptureRect: Rect,
	Disabled: boolean?,
}

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()

	local propertiesRef = React.useRef(nil)
	local propertiesAbsSize = Hooks.useRefProperty(propertiesRef, "AbsoluteSize", Vector2.zero)

	local animationRef = React.useRef(nil)
	local animationAbsSize = Hooks.useRefProperty(animationRef, "AbsoluteSize", Vector2.zero)

	local forceRender = Hooks.useUpdate()
	local listRef = React.useRef({} :: InstanceList.List<PVInstance>)
	local nList = #listRef.current

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = -1, -- Fixes dropdown issues
	}, {
		Overlay = props.Disabled and React.createElement("Frame", {
			BackgroundTransparency = 0.7,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			LoadingDots = React.createElement(StudioComponents.LoadingDots, {}),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -BUTTONS_HEIGHT),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Properties = React.createElement(Properties, {
				ObservableState = props.ObservableState,
				CaptureRect = props.CaptureRect,
				Disabled = props.Disabled,
				LayoutOrder = 1,
				ref = propertiesRef,
			}),

			InstanceList = React.createElement(InstanceList, {
				Size = UDim2.new(1, 0, 1, -(propertiesAbsSize.Y + animationAbsSize.Y)),

				ForceRender = forceRender,
				ListRef = listRef,

				OnListElementAdded = props.OnListElementAdded,
				OnListElementSelected = props.OnListElementSelected,
				OnListElementRemoved = props.OnListElementRemoved,

				FilterSelection = function(instance)
					return if instance:IsA("PVInstance") then instance else nil
				end,

				Disabled = props.Disabled,
				LayoutOrder = 3,
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

			CaptureAll = React.createElement(StudioComponents.Button, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "Capture All",
				Disabled = nList == 0 or not not props.Disabled,
				LayoutOrder = 1,

				OnActivated = function()
					props.OnCaptureAll()
				end,

				Icon = {
					Image = CAPTURE_ALL_ICON.Url,
					RectSize = CAPTURE_ALL_ICON.ImageRectSize,
					RectOffset = CAPTURE_ALL_ICON.ImageRectOffset,
					Size = Vector2.new(CAPTURE_ALL_ICON.ImageRectSize.X, CAPTURE_ALL_ICON.ImageRectSize.Y),
					UseThemeColor = true,
				},
			}),

			Capture = React.createElement(StudioComponents.MainButton, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "Capture",
				Disabled = nList == 0 or not not props.Disabled,
				LayoutOrder = 2,

				OnActivated = function()
					props.OnCapture()
				end,

				Icon = {
					Image = CAPTURE_ICON.Url,
					RectSize = CAPTURE_ICON.ImageRectSize,
					RectOffset = CAPTURE_ICON.ImageRectOffset,
					Size = Vector2.new(CAPTURE_ICON.ImageRectSize.X, CAPTURE_ICON.ImageRectSize.Y),
					UseThemeColor = true,
				},
			}),
		}),
	})
end

return Widget
