local pluginRoot = script:FindFirstAncestor("PluginRoot")

local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local GroupHeader = require(script.GroupHeader)
local StrokeLayer = require(script.Layers.StrokeLayer)
local DropShadowLayer = require(script.Layers.DropShadowLayer)

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
	local layers, updateLayers = props.Controller:use()

	local layerNodes: { [string]: React.ReactNode } = {}
	for i, layer in layers do
		local component: React.FC<any>
		if layer.kind == "Stroke" then
			component = StrokeLayer
		elseif layer.kind == "Drop Shadow" then
			component = DropShadowLayer
		end

		if component then
			local function updateLayer(callback: (Controller.Layer) -> Controller.Layer?)
				updateLayers(function(layers)
					local newLayer = callback(layers[i])
					if newLayer then
						layers[i] = newLayer
					else
						table.remove(layers, i)
					end
					return layers
				end)
			end

			layerNodes["Layer" .. i] = React.createElement(GroupHeader, {
				GroupName = layer.name,
				LayoutOrder = props.LayoutOrder,
				Disabled = props.Disabled,

				OnTrashActivated = function()
					updateLayer(function(layer)
						return nil
					end)
				end,

				OnMoveActivated = function(step)
					local switchLayer = layers[i + step]
					if switchLayer then
						updateLayers(function(layers)
							layers[i] = switchLayer
							layers[i + step] = layer
							return layers
						end)
					end
				end,
			}, {
				React.createElement(component, {
					Layer = layer,
					UpdateLayer = updateLayer,
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
			}, layerNodes),

			Padding = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
				LayoutOrder = 2,
			}),
		}),
	})
end

return Effects
