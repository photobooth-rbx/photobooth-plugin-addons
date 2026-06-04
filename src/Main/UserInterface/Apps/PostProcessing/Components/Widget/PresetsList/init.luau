local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local SCROLL_GRADIENT_INSET_HEIGHT = 22
local ADD_EFFECT_BUTTON_HEIGHT = 32
local SAVE_ICON = assert(Lucide.GetAsset("save", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Controller: Controller.PostProcessingController,
	OnButtonActivated: () -> (),

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function PresetsList(props: Props)
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Scroll = React.createElement(StudioProperties.VerticalScroll, {
			Size = UDim2.new(1, 0, 1, -ADD_EFFECT_BUTTON_HEIGHT),
			GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
			ScrollInset = UDim.new(0, -2),
			ScrollBarTransparency = 0.7,
			ScrollBarFades = true,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Layers = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 1,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
			}),

			Padding = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
				LayoutOrder = 2,
			}),
		}),

		AddNewPreset = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, ADD_EFFECT_BUTTON_HEIGHT),
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
					Text = "Add Preset",
					Disabled = props.Disabled,

					Icon = {
						Image = SAVE_ICON.Url,
						RectSize = SAVE_ICON.ImageRectSize,
						RectOffset = SAVE_ICON.ImageRectOffset,
						Size = Vector2.new(SAVE_ICON.ImageRectSize.X, SAVE_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},

					OnActivated = function()
						props.OnButtonActivated()
					end,
				}),
			}),
		}),
	})
end

return PresetsList
