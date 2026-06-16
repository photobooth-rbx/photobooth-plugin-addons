local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)
local Effects = require(postProcessingRoot.Effects)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local widgetRoot = script:FindFirstAncestor("Widget")
local EffectDialog = require(widgetRoot.EffectDialog)

local Layer = require(script.Layer)
local Effect = require(script.Effect)
local UnderlineIconButton = require(script.UnderlineIconButton)

local SCROLL_GRADIENT_INSET_HEIGHT = 22
local MIDDLE_BAR_HEIGHT = 22

local SPARKLES_ICON = assert(Lucide.GetAsset("sparkles", 16))
local PLUS_ICON = assert(Lucide.GetAsset("plus", 16))
local UP_ICON = assert(Lucide.GetAsset("chevron-up", 16))
local DOWN_ICON = assert(Lucide.GetAsset("chevron-down", 16))
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

-- Selection is purely UI state: a layer is selected when effectId is nil, otherwise
-- the sub-effect within that layer is selected. The layer/effect data lives in the
-- Controller.
type Selection = { layerId: string, effectId: string? }

local function makeSelection(layerId: string, effectId: string?): Selection
	return { layerId = layerId, effectId = effectId }
end

local function EffectsList(props: Props)
	local theme = StudioComponents.useTheme()
	local controller = props.Controller

	local layers = controller:useLayers()
	local thumbnails = controller:useThumbnails()
	local selection, setSelection = React.useState(nil :: Selection?)

	-- The add-effect dialog targets a layer captured when it opens, so changing the
	-- selection afterwards (it can't, while the overlay blocks input) won't matter.
	local pendingLayerId, setPendingLayerId = React.useState(nil :: string?)
	local isDialogOpen = pendingLayerId ~= nil

	local openAddEffect = function()
		local targetLayerId = if selection then selection.layerId elseif layers[#layers] then layers[#layers].id else nil
		if targetLayerId then
			setPendingLayerId(targetLayerId)
		end
	end

	local confirmAddEffect = function(name: string, kind: string)
		local targetLayerId = pendingLayerId
		setPendingLayerId(nil :: any)
		if not targetLayerId then
			return
		end

		local effectId = controller:addEffect(targetLayerId, kind, name)
		setSelection(makeSelection(targetLayerId, effectId))
	end

	local addLayer = function()
		setSelection(makeSelection(controller:addLayer()))
	end

	local moveSelected = function(step: number)
		if not selection then
			return
		end

		if selection.effectId then
			controller:moveEffect(selection.layerId, selection.effectId, step)
		else
			controller:moveLayer(selection.layerId, step)
		end
	end

	local deleteSelected = function()
		if not selection then
			return
		end

		if selection.effectId then
			controller:removeEffect(selection.layerId, selection.effectId)
		else
			controller:removeLayer(selection.layerId)
		end
		setSelection(nil :: any)
	end

	-- Resolve the current selection against the live state.

	local selectedLayer: Controller.Layer?
	local selectedEffect: Controller.LayerEffect?
	if selection then
		for _, layer in layers do
			if layer.id == selection.layerId then
				selectedLayer = layer
				if selection.effectId then
					for _, item in layer.effects do
						if item.id == selection.effectId then
							selectedEffect = item
							break
						end
					end
				end
				break
			end
		end
	end

	-- ScrollTop tree

	local layerNodes: { [string]: React.ReactNode } = {}
	for layerOrder, layer in layers do
		local thumbnail = thumbnails[layer.id]

		local effectNodes: { [string]: React.ReactNode } = {}
		for effectOrder, item in layer.effects do
			effectNodes["Effect_" .. item.id] = React.createElement(Effect, {
				Title = item.effect.name,
				IsVisible = item.isVisible,
				IsSelected = selection ~= nil and selection.layerId == layer.id and selection.effectId == item.id,
				LayoutOrder = effectOrder,
				Disabled = props.Disabled,

				OnSelected = function()
					setSelection(makeSelection(layer.id, item.id))
				end,
				OnVisibilityToggled = function()
					controller:toggleEffectVisibility(layer.id, item.id)
				end,
			})
		end

		layerNodes["Layer_" .. layer.id] = React.createElement(Layer, {
			Title = layer.name,
			Image = if thumbnail then Content.fromObject(thumbnail) else nil,
			IsVisible = layer.isVisible,
			IsSelected = selection ~= nil and selection.layerId == layer.id and selection.effectId == nil,
			IsExpanded = layer.isExpanded,
			LayoutOrder = layerOrder,
			Disabled = props.Disabled,

			OnSelected = function()
				setSelection(makeSelection(layer.id))
			end,
			OnVisibilityToggled = function()
				controller:toggleLayerVisibility(layer.id)
			end,
			OnExpandToggled = function()
				controller:toggleLayerExpanded(layer.id)
			end,
		}, effectNodes)
	end

	-- ScrollBottom properties

	local propertyNodes: { [string]: React.ReactNode } = {}
	if selectedEffect and selection then
		local component = Effects.getReactComponentByKind(selectedEffect.effect.kind)
		local layerId, effectId = selection.layerId, selection.effectId :: string

		propertyNodes.Name = React.createElement(StudioProperties.String, {
			FieldName = "Name",
			Value = selectedEffect.effect.name,
			Disabled = props.Disabled,
			LayoutOrder = 1,

			OnValueSubmitted = function(newName)
				controller:setEffectName(layerId, effectId, newName)
			end,
		})

		propertyNodes.Body = component
			and React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			}, {
				Component = React.createElement(component, {
					Effect = selectedEffect.effect,
					Disabled = props.Disabled,
					UpdateEffect = function(transform)
						controller:updateEffect(layerId, effectId, transform)
					end,
				}),
			})
	elseif selectedLayer then
		local layerId = selectedLayer.id

		propertyNodes.Name = React.createElement(StudioProperties.String, {
			FieldName = "Name",
			Value = selectedLayer.name,
			Disabled = props.Disabled,
			LayoutOrder = 1,

			OnValueSubmitted = function(newName)
				controller:setLayerName(layerId, newName)
			end,
		})

		propertyNodes.Visible = React.createElement(StudioProperties.Boolean, {
			FieldName = "Visible",
			Value = selectedLayer.isVisible,
			Disabled = props.Disabled,
			LayoutOrder = 2,

			OnValueSubmitted = function()
				controller:toggleLayerVisibility(layerId)
			end,
		})

		propertyNodes.ShowBaseImage = React.createElement(StudioProperties.Boolean, {
			FieldName = "Show Base Image",
			Value = selectedLayer.showBaseImage,
			Disabled = props.Disabled,
			LayoutOrder = 3,

			OnValueSubmitted = function(newValue)
				controller:setLayerShowBaseImage(layerId, newValue)
			end,
		})

		propertyNodes.Offset = React.createElement(StudioProperties.Vector2, {
			FieldName = "Offset",
			Value = selectedLayer.offset,
			Disabled = props.Disabled,
			LayoutOrder = 4,

			OnValueSubmitted = function(newValue)
				controller:setLayerOffset(layerId, newValue)
			end,
		})

		propertyNodes.Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",
			Min = 0,
			Max = 1,
			Value = selectedLayer.transparency,
			Disabled = props.Disabled,
			LayoutOrder = 5,

			OnValueSubmitted = function(newValue)
				controller:setLayerTransparency(layerId, newValue)
			end,
		})

		propertyNodes.Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Tint Color",
			Value = selectedLayer.tintColor,
			Disabled = props.Disabled,
			LayoutOrder = 6,

			OnValueSubmitted = function(newValue)
				controller:setLayerTint(layerId, newValue)
			end,
		})
	else
		propertyNodes.Empty = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 48),
			FontFace = Font.fromName("SourceSansPro"),
			Text = "Select a layer or effect to edit its properties.",
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

	local hasSelection = selection ~= nil

	local function toolbarButton(icon, layoutOrder: number, disabled: boolean?, onActivated: () -> ())
		return React.createElement(LucideIconButton, {
			Size = UDim2.fromOffset(22, 22),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = icon,
			Disabled = disabled,
			LayoutOrder = layoutOrder,
			OnActivated = onActivated,
		})
	end

	-- The "add" actions get text labels so it's clear which creates a layer vs an
	-- effect; the directional move/delete actions stay as compact icons.
	local function addButton(text: string, icon, layoutOrder: number, disabled: boolean?, onActivated: () -> ())
		return React.createElement(UnderlineIconButton, {
			Text = text,
			Icon = icon,
			Disabled = disabled,
			LayoutOrder = layoutOrder,
			OnActivated = onActivated,
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
		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			ScrollTop = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.new(1, 0, 0.5, -MIDDLE_BAR_HEIGHT / 2),
				GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
				ScrollInset = UDim.new(0, -2),
				ScrollBarTransparency = 0.7,
				ScrollBarFades = true,
				LayoutOrder = 1,
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
				}, layerNodes),

				Padding = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
					LayoutOrder = 2,
				}),
			}),

			MiddleBar = React.createElement("Frame", {
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				Size = UDim2.new(1, 0, 0, MIDDLE_BAR_HEIGHT),
				LayoutOrder = 2,
			}, {
				Left = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),

					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),

					AddLayer = addButton("Add Layer", PLUS_ICON, 1, props.Disabled, addLayer),
					AddEffect = addButton(
						"Add Effect",
						SPARKLES_ICON,
						2,
						props.Disabled or #layers == 0,
						openAddEffect
					),
				}),

				Right = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),

					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),

					MoveUp = toolbarButton(UP_ICON, 4, props.Disabled or not hasSelection, function()
						moveSelected(-1)
					end),
					MoveDown = toolbarButton(DOWN_ICON, 5, props.Disabled or not hasSelection, function()
						moveSelected(1)
					end),
					Delete = toolbarButton(TRASH_ICON, 6, props.Disabled or not hasSelection, deleteSelected),
				}),
			}),

			ScrollBottom = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.new(1, 0, 0.5, -MIDDLE_BAR_HEIGHT / 2),
				GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
				ScrollInset = UDim.new(0, -2),
				ScrollBarTransparency = 0.7,
				ScrollBarFades = true,
				LayoutOrder = 3,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				Properties = React.createElement("Frame", {
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
				}, propertyNodes),

				Padding = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
					LayoutOrder = 2,
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

				Controller = props.Controller,

				OnConfirm = function(name, kind)
					confirmAddEffect(name, kind)
				end,

				OnCancel = function()
					setPendingLayerId(nil :: any)
				end,
			}),
		}),
	})
end

return EffectsList
