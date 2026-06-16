local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local SCROLL_GRADIENT_INSET_HEIGHT = 22
local ADD_EFFECT_BUTTON_HEIGHT = 32
local SAVE_ICON = assert(Lucide.GetAsset("save", 16))
local TRASH_ICON = assert(Lucide.GetAsset("trash", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Controller: Controller.PostProcessingController,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

type PresetRowProps = {
	Name: string,
	LayoutOrder: number,
	Disabled: boolean?,
	OnApply: () -> (),
	OnDelete: () -> (),
}

local function PresetRow(props: PresetRowProps)
	local theme = StudioComponents.useTheme()
	local isHovered, setIsHovered = React.useState(false)

	return React.createElement("Frame", {
		Active = true,
		BackgroundColor3 = if isHovered and not props.Disabled
			then theme:GetColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Hover)
			else theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = props.LayoutOrder,

		[React.Event.InputBegan] = function(_, input: InputObject)
			if not props.Disabled and input.UserInputType == Enum.UserInputType.MouseButton1 then
				props.OnApply()
			end
		end,
		[React.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 8),
			PaddingRight = UDim.new(0, 4),
		}),

		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -28, 1, 0),
			FontFace = Font.fromName("SourceSansPro"),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = theme:GetColor(
				Enum.StudioStyleGuideColor.MainText,
				if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
			),
			Text = props.Name,
			TextSize = 14,
			LayoutOrder = 1,
		}),

		Delete = React.createElement(LucideIconButton, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(24, 24),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = TRASH_ICON,
			Disabled = props.Disabled,
			LayoutOrder = 2,
			OnActivated = props.OnDelete,
		}),
	})
end

local function PresetsList(props: Props)
	local theme = StudioComponents.useTheme()
	local controller = props.Controller

	local presets = controller:usePresets()

	local presetNodes: { [string]: React.ReactNode } = {}
	for order, preset in presets do
		presetNodes["Preset_" .. preset.id] = React.createElement(PresetRow, {
			Name = preset.name,
			LayoutOrder = order,
			Disabled = props.Disabled,

			OnApply = function()
				controller:applyPreset(preset.id)
			end,
			OnDelete = function()
				controller:removePreset(preset.id)
			end,
		})
	end

	if #presets == 0 then
		presetNodes.Empty = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 48),
			FontFace = Font.fromName("SourceSansPro"),
			Text = "Add a preset to save your current layers and effects.",
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

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
			}, presetNodes),

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
						controller:addPreset()
					end,
				}),
			}),
		}),
	})
end

return PresetsList
