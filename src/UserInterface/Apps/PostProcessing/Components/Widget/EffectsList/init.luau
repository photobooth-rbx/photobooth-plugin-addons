local ReplicatedStorage = game:GetService("ReplicatedStorage")
local pluginRoot = script:FindFirstAncestor("PluginRoot")

local ObservableValue = require(ReplicatedStorage.PluginRoot.Utilities.ObservableValue)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local GroupHeader = require(script.GroupHeader)
local BaseImageEffect = require(script.Components.BaseImageLayer)
local StrokeEffect = require(script.Components.StrokeLayer)
local DropShadowEffect = require(script.Components.DropShadowLayer)

local SCROLL_GRADIENT_INSET_HEIGHT = 22

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Controller: Controller.PostProcessingController,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

type EffectProps = {
	Controller: Controller.PostProcessingController,
	ObservableEffect: ObservableValue.ObservableValue<Controller.Effect>,
	LayoutOrder: number,
	Disabled: boolean?,
}

local function EffectComponent(props: EffectProps)
	local effect, updateEffect = props.ObservableEffect:use()

	local component: React.FC<any>
	if effect.kind == "Base Image" then
		component = BaseImageEffect
	elseif effect.kind == "Stroke" then
		component = StrokeEffect
	elseif effect.kind == "Drop Shadow" then
		component = DropShadowEffect
	end

	return React.createElement(GroupHeader, {
		GroupName = effect.name,
		LayoutOrder = props.LayoutOrder,
		Disabled = props.Disabled,

		OnTrashActivated = if effect.playerCreated
			then function()
				props.Controller.observableEffects:update()(function(effects)
					table.remove(effects, props.LayoutOrder)
					return effects
				end)
			end
			else nil,

		OnMoveActivated = function(step)
			local i = props.LayoutOrder
			local j = i + step
			if props.Controller.observableEffects:get()[j] then
				props.Controller.observableEffects:update()(function(effects)
					local observedEffectA = effects[i]
					local observedEffectB = effects[j]

					observedEffectA:update()(function(effectA: any)
						effectA.index = j
						return effectA
					end)

					observedEffectB:update()(function(effectB: any)
						effectB.index = i
						return effectB
					end)

					effects[i] = observedEffectB
					effects[j] = observedEffectA

					return effects
				end)
			end
		end,
	}, {
		React.createElement(component, {
			Effect = effect,
			UpdateEffect = updateEffect,
			Disabled = props.Disabled,
		}),
	})
end

local function EffectsList(props: Props)
	local observableEffects = props.Controller:useEffects()

	local effectNodes: { [string]: React.ReactNode } = {}
	for i, observableEffect in observableEffects do
		effectNodes["Effect" .. i] = React.createElement(EffectComponent, {
			Controller = props.Controller,
			ObservableEffect = observableEffect :: any,
			LayoutOrder = i,
			Disabled = props.Disabled,
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
			Size = UDim2.fromScale(1, 1),
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
			}, effectNodes),

			Padding = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
				LayoutOrder = 2,
			}),
		}),
	})
end

return EffectsList
