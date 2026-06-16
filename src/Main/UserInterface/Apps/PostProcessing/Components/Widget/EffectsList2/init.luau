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
	OnButtonActivated: () -> (),

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

-- Local (mock) state model. Layers own an ordered list of sub-effects; each effect
-- wraps a Controller.Effect record so the existing effect editor Components can be
-- reused verbatim in the properties panel.

type EffectItem = {
	id: string,
	isVisible: boolean,
	effect: Controller.Effect<any>,
}

type LayerItem = {
	id: string,
	name: string,
	isVisible: boolean,
	isExpanded: boolean,
	effects: { EffectItem },
}

type Selection = { layerId: string, effectId: string? }

local function makeSelection(layerId: string, effectId: string?): Selection
	return { layerId = layerId, effectId = effectId }
end

local idCounter = 0
local function nextId(): string
	idCounter += 1
	return tostring(idCounter)
end

local function createEffectItem(kind: string, name: string): EffectItem
	local entry = assert(Effects.getByKind(kind))
	return {
		id = nextId(),
		isVisible = true,
		effect = {
			kind = kind,
			name = name,
			index = 0,
			playerCreated = entry.playerCreated,
			renderTicket = 0,
			properties = entry.create(),
		},
	}
end

local function createLayer(name: string): LayerItem
	return {
		id = nextId(),
		name = name,
		isVisible = true,
		isExpanded = true,
		effects = {},
	}
end

local function indexOf<T>(list: { T }, predicate: (T) -> boolean): number?
	for i, value in list do
		if predicate(value) then
			return i
		end
	end
	return nil
end

local function cloneLayer(layer: LayerItem): LayerItem
	local clone = table.clone(layer)
	clone.effects = table.clone(layer.effects)
	return clone
end

-- Returns a new layers array with `fn` applied to the layer matching `layerId`.
local function mapLayer(layers: { LayerItem }, layerId: string, fn: (LayerItem) -> LayerItem): { LayerItem }
	local out = table.clone(layers)
	for i, layer in out do
		if layer.id == layerId then
			out[i] = fn(layer)
			break
		end
	end
	return out
end

local function EffectsList(props: Props)
	local theme = StudioComponents.useTheme()

	local layers, setLayers = React.useState(function(): { LayerItem }
		local imageLayer = createLayer("Image")
		table.insert(imageLayer.effects, createEffectItem("Stroke", "Stroke"))
		return { imageLayer }
	end)

	local selection, setSelection = React.useState(nil :: Selection?)

	-- The add-effect dialog targets a layer captured when it opens, so changing the
	-- selection afterwards (it can't, while the overlay blocks input) won't matter.
	local pendingLayerId, setPendingLayerId = React.useState(nil :: string?)
	local isDialogOpen = pendingLayerId ~= nil

	-- Mutations

	local toggleLayerVisibility = function(layerId: string)
		setLayers(function(prev)
			return mapLayer(prev, layerId, function(layer)
				local clone = cloneLayer(layer)
				clone.isVisible = not clone.isVisible
				return clone
			end)
		end)
	end

	local toggleLayerExpanded = function(layerId: string)
		setLayers(function(prev)
			return mapLayer(prev, layerId, function(layer)
				local clone = cloneLayer(layer)
				clone.isExpanded = not clone.isExpanded
				return clone
			end)
		end)
	end

	local toggleEffectVisibility = function(layerId: string, effectId: string)
		setLayers(function(prev)
			return mapLayer(prev, layerId, function(layer)
				local clone = cloneLayer(layer)
				local i = indexOf(clone.effects, function(item)
					return item.id == effectId
				end)
				if i then
					local item = table.clone(clone.effects[i])
					item.isVisible = not item.isVisible
					clone.effects[i] = item
				end
				return clone
			end)
		end)
	end

	local setLayerName = function(layerId: string, name: string)
		setLayers(function(prev)
			return mapLayer(prev, layerId, function(layer)
				local clone = cloneLayer(layer)
				clone.name = name
				return clone
			end)
		end)
	end

	-- Applies a Controller-style effect transform to a single effect record. This is
	-- the bridge that lets the registered effect editor Components drive local state.
	local updateEffect = function(layerId: string, effectId: string, transform: (any) -> any)
		setLayers(function(prev)
			return mapLayer(prev, layerId, function(layer)
				local clone = cloneLayer(layer)
				local i = indexOf(clone.effects, function(item)
					return item.id == effectId
				end)
				if i then
					local item = table.clone(clone.effects[i])
					local effect = table.clone(item.effect)
					effect.properties = table.clone(item.effect.properties)
					item.effect = transform(effect)
					clone.effects[i] = item
				end
				return clone
			end)
		end)
	end

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

		local item = createEffectItem(kind, name)
		setLayers(function(prev)
			return mapLayer(prev, targetLayerId, function(layer)
				local clone = cloneLayer(layer)
				clone.isExpanded = true
				table.insert(clone.effects, item)
				return clone
			end)
		end)
		setSelection(makeSelection(targetLayerId, item.id))
	end

	local addLayer = function()
		local layer = createLayer("Layer")
		setLayers(function(prev)
			local out = table.clone(prev)
			table.insert(out, layer)
			return out
		end)
		setSelection(makeSelection(layer.id))
	end

	local moveSelected = function(step: number)
		if not selection then
			return
		end

		if selection.effectId then
			setLayers(function(prev)
				return mapLayer(prev, selection.layerId, function(layer)
					local clone = cloneLayer(layer)
					local i = indexOf(clone.effects, function(item)
						return item.id == selection.effectId
					end)
					local j = if i then i + step else nil
					if i and j and clone.effects[j] then
						clone.effects[i], clone.effects[j] = clone.effects[j], clone.effects[i]
					end
					return clone
				end)
			end)
		else
			setLayers(function(prev)
				local out = table.clone(prev)
				local i = indexOf(out, function(layer)
					return layer.id == selection.layerId
				end)
				local j = if i then i + step else nil
				if i and j and out[j] then
					out[i], out[j] = out[j], out[i]
				end
				return out
			end)
		end
	end

	local deleteSelected = function()
		if not selection then
			return
		end

		if selection.effectId then
			setLayers(function(prev)
				return mapLayer(prev, selection.layerId, function(layer)
					local clone = cloneLayer(layer)
					local i = indexOf(clone.effects, function(item)
						return item.id == selection.effectId
					end)
					if i then
						table.remove(clone.effects, i)
					end
					return clone
				end)
			end)
		else
			setLayers(function(prev)
				local out = table.clone(prev)
				local i = indexOf(out, function(layer)
					return layer.id == selection.layerId
				end)
				if i then
					table.remove(out, i)
				end
				return out
			end)
		end
		setSelection(nil :: any)
	end

	-- Resolve the current selection against the live state.

	local selectedLayer: LayerItem?
	local selectedEffect: EffectItem?
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
					toggleEffectVisibility(layer.id, item.id)
				end,
			})
		end

		layerNodes["Layer_" .. layer.id] = React.createElement(Layer, {
			Title = layer.name,
			IsVisible = layer.isVisible,
			IsSelected = selection ~= nil and selection.layerId == layer.id and selection.effectId == nil,
			IsExpanded = layer.isExpanded,
			LayoutOrder = layerOrder,
			Disabled = props.Disabled,

			OnSelected = function()
				setSelection(makeSelection(layer.id))
			end,
			OnVisibilityToggled = function()
				toggleLayerVisibility(layer.id)
			end,
			OnExpandToggled = function()
				toggleLayerExpanded(layer.id)
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
				updateEffect(layerId, effectId, function(effect)
					effect.name = newName
					return effect
				end)
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
						updateEffect(layerId, effectId, transform)
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
				setLayerName(layerId, newName)
			end,
		})

		propertyNodes.Visible = React.createElement(StudioProperties.Boolean, {
			FieldName = "Visible",
			Value = selectedLayer.isVisible,
			Disabled = props.Disabled,
			LayoutOrder = 2,

			OnValueSubmitted = function()
				toggleLayerVisibility(layerId)
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
