local pluginRoot = script:FindFirstAncestor("PluginRoot")

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

local function Effects(props: Props)
	local effects, updateEffects = props.Controller:useEffects()
	local effectNodes: { [string]: React.ReactNode } = {}
	for i, effect in effects do
		local component: React.FC<any>
		if effect.kind == "Base Image" then
			component = BaseImageEffect
		elseif effect.kind == "Stroke" then
			component = StrokeEffect
		elseif effect.kind == "Drop Shadow" then
			component = DropShadowEffect
		end

		if component then
			local function updateEffect(callback: (Controller.Effect) -> Controller.Effect?)
				updateEffects(function(effects)
					local newEffect = callback(effects[i])
					if newEffect then
						effects[i] = newEffect
					else
						table.remove(effects, i)
					end
					return effects
				end)
			end

			effectNodes["Effect" .. i] = React.createElement(GroupHeader, {
				GroupName = effect.name,
				LayoutOrder = props.LayoutOrder,
				Disabled = props.Disabled,

				OnTrashActivated = if props.Controller:isEffectPublic(effect.kind)
					then function()
						updateEffect(function(layer)
							return nil
						end)
					end
					else nil,

				OnMoveActivated = function(step)
					local switchLayer = effects[i + step]
					if switchLayer then
						updateEffects(function(effects)
							effects[i] = switchLayer
							effects[i + step] = effect
							return effects
						end)
					end
				end,
			}, {
				React.createElement(component, {
					Effect = effect,
					UpdateEffect = updateEffect,
					LayoutOrder = i,
					Disabled = props.Disabled,
				}),
			})
		end
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

return Effects
