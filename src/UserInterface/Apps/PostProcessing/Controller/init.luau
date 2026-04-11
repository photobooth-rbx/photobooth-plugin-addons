local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Timeout = require(pluginRoot.Utilities.Timeout)
local Image = require(pluginRoot.Utilities.Image)

local EdgeVectorField = require(script.EdgeVectorField)
local IntegralImage = require(script.IntegralImage)

local EXHAUSTION_STEP = 1 / 60

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

function PostProcessingControllerStatic.createRenderState()
	return ObservableValue.new({
		StrokeThickness = 0,
		StrokeSoftness = 1,

		DropShadowSpread = 0,
		DropShadowBlur = 0,
		DropShadowOffset = Vector2.zero,
	})
end

function PostProcessingControllerStatic.createNonRenderState()
	return ObservableValue.new({
		StrokeTransparency = 0,
		StrokeColor = Color3.new(0, 0, 0),

		DropShadowTransparency = 1,
		DropShadowColor = Color3.new(0, 0, 0),
	})
end

function PostProcessingControllerStatic.new(
	observableRenderState: ObservableRenderState,
	observableNonRenderState: ObservableNonRenderState
)
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.trove = Trove.new()

	self.observableRenderState = observableRenderState
	self.observableNonRenderState = observableNonRenderState

	self.observableLoadState = ObservableValue.new({
		editImage = nil,
		evfBuffer = nil,
	})

	return self
end

-- Private

local function smoothStep(edge0: number, edge1: number, x: number)
	if edge1 <= edge0 then
		return if x <= edge0 then 0 else 1
	end
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
end

local function blendRGBA(rgbaArr: { { number } })
	local b = rgbaArr[1]

	for i = 2, #rgbaArr do
		local a = rgbaArr[i]

		local aAlpha = a[4] / 255
		local bAlpha = b[4] / 255

		local outAlpha = aAlpha + bAlpha * (1 - aAlpha)
		local newB = { 0, 0, 0, outAlpha * 255 }

		if outAlpha > 0 then
			for j = 1, 3 do
				newB[j] = (a[j] * aAlpha + b[j] * bAlpha * (1 - aAlpha)) / outAlpha
			end
		end

		b = newB
	end

	return b
end

function PostProcessingControllerClass._getEditImagesAsync(self: PostProcessingController, loadState: LoadState?)
	local baseEditImage = self.observableLoadState:get().editImage
	local editImages: EditImages = { Base = baseEditImage }

	local evfBuffer = loadState and loadState.evfBuffer

	if baseEditImage and evfBuffer then
		local tryYield = Timeout.scriptExhaustionStepper(EXHAUSTION_STEP)
		local renderState = self.observableRenderState:get()

		local img = Image.fromEditableImage(baseEditImage)
		local width = img:GetWidth()
		local height = img:GetHeight()

		local strokeImg = img:Clone()
		local shadowImg = strokeImg:Clone()

		local strokeThickness = renderState.StrokeThickness
		local strokeSoftness = renderState.StrokeSoftness

		local shadowBlur = renderState.DropShadowBlur
		local shadowSpread = renderState.DropShadowSpread
		local shadowOffset = renderState.DropShadowOffset

		local function readSignedDistance(x: number, y: number)
			local i = x + (y - 1) * width
			local j = (i - 1) * 4

			local ox = buffer.readi16(evfBuffer, j + 0) / 2
			local oy = buffer.readi16(evfBuffer, j + 2) / 2

			local _, _, _, alpha = img:GetRGBA255(i)
			local sign = (math.sign(alpha) * 2) - 1

			return -sign * math.sqrt(ox * ox + oy * oy)
		end

		local shadowIntImg = IntegralImage.fromImage(img, function(u32, x, y)
			tryYield()
			return if readSignedDistance(x, y) <= shadowSpread then 255 else 0
		end)

		for y = 1, height do
			for x = 1, width do
				tryYield()

				local i = x + (y - 1) * width

				local strokeRGBA = { 255, 255, 255, 0 }
				if strokeThickness > 0 then
					local signedDistance = readSignedDistance(x, y)
					local strokeAlpha = 1
						- smoothStep(strokeThickness - strokeSoftness, strokeThickness + strokeSoftness, signedDistance)
					strokeRGBA[4] = strokeAlpha * 255
				end

				strokeImg:SetRGBA255(i, strokeRGBA[1], strokeRGBA[2], strokeRGBA[3], strokeRGBA[4])

				local dx = x - shadowOffset.X
				local dy = y - shadowOffset.Y
				local shadowAlphaSum = shadowIntImg:ReadRadius(dx, dy, shadowBlur)
				local shadowBoxSide = 2 * shadowBlur + 1

				shadowImg:SetRGBA255(i, 255, 255, 255, shadowAlphaSum / (shadowBoxSide * shadowBoxSide))
			end
		end

		editImages.Stroke = strokeImg:Save()
		editImages.DropShadow = shadowImg:Save()
	end

	return editImages
end

function PostProcessingControllerClass._getLayers(self: PostProcessingController, editImages: EditImages)
	local layers: { Layer } = {}
	local nonRenderState = self.observableNonRenderState:get()

	if editImages.DropShadow then
		table.insert(layers, {
			EditableImage = editImages.DropShadow,
			Transparency = nonRenderState.DropShadowTransparency,
			Color = nonRenderState.DropShadowColor,
		})
	end

	if editImages.Stroke then
		table.insert(layers, {
			EditableImage = editImages.Stroke,
			Transparency = nonRenderState.StrokeTransparency,
			Color = nonRenderState.StrokeColor,
		})
	end

	if editImages.Base then
		table.insert(layers, {
			EditableImage = editImages.Base,
			Transparency = 0,
			Color = Color3.new(1, 1, 1),
		})
	end

	return layers
end

-- Public

function PostProcessingControllerClass.clear(self: PostProcessingController)
	self.trove:Clean()
	self.observableLoadState:set({
		editImage = nil,
		evfBuffer = nil,
	})
end

function PostProcessingControllerClass.loadAsync(self: PostProcessingController, editImage: EditableImage)
	self:clear()

	self.observableLoadState:update()(function(state)
		state.editImage = editImage
		return state
	end)

	-- use a future here so that clearing the trove will unblock the calling thread
	local loadedFuture = Future.new()

	self.trove:Add(function()
		if not loadedFuture:isCompleted() then
			loadedFuture:complete()
		end
	end)

	self.trove:Add(task.spawn(function()
		local tryYield = Timeout.scriptExhaustionStepper(EXHAUSTION_STEP)

		local img = Image.fromEditableImage(editImage)
		local evfBuffer = EdgeVectorField.generate(img, tryYield)

		self.observableLoadState:update()(function(state)
			state.evfBuffer = evfBuffer
			return state
		end)

		loadedFuture:complete()
	end))

	loadedFuture:expect()
end

function PostProcessingControllerClass.useLayers(self: PostProcessingController)
	local editImages, setEditImages = React.useState(self:_getEditImagesAsync(nil))

	local loadState, loadStateDep = self.observableLoadState:use()
	local _, renderStateDep = self.observableRenderState:use()
	local _, nonRenderStateDep = self.observableNonRenderState:use()

	React.useEffect(function()
		local thread = task.spawn(function()
			local newEditImages = self:_getEditImagesAsync(loadState)
			setEditImages(newEditImages)
		end)

		return function()
			task.cancel(thread)
		end
	end, { loadStateDep, renderStateDep } :: { any })

	local layers = React.useMemo(function()
		return self:_getLayers(editImages)
	end, { editImages, nonRenderStateDep } :: { any })

	return layers
end

function PostProcessingControllerClass.composeAsync(self: PostProcessingController)
	assert(self.observableLoadState:get().editImage, "No image loaded.")
	while not self.observableLoadState:get().evfBuffer do
		self.observableLoadState:waitForChange()
	end

	local editImages = self:_getEditImagesAsync(self.observableLoadState:get())
	local layers = self:_getLayers(editImages)

	local tryYield = Timeout.scriptExhaustionStepper(EXHAUSTION_STEP)

	local imgByLayer = {}
	for _, layer in layers do
		imgByLayer[layer] = Image.fromEditableImage(layer.EditableImage)
	end

	local composited = imgByLayer[layers[1]]:Clone()
	for i = 1, composited:GetNumberOfPixels() do
		tryYield()

		local pixels = {}
		for _, layer in layers do
			local tint = layer.Color
			local r, g, b, a = imgByLayer[layer]:GetRGBA255(i)
			table.insert(pixels, { tint.R * r, tint.G * g, tint.B * b, a * (1 - layer.Transparency) })
		end

		local blended = blendRGBA(pixels)
		composited:SetRGBA255(i, blended[1], blended[2], blended[3], blended[4])
	end

	return composited:Save()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.trove:Destroy()
end

type ObservableValue<T> = ObservableValue.ObservableValue<T>

type EditImages = {
	Base: EditableImage?,
	Stroke: EditableImage?,
	DropShadow: EditableImage?,
}

export type Layer = {
	EditableImage: EditableImage,
	Transparency: number,
	Color: Color3,
}

export type RenderState = typeof(PostProcessingControllerStatic.createRenderState():get())
export type ObservableRenderState = ObservableValue<RenderState>

export type NonRenderState = typeof(PostProcessingControllerStatic.createNonRenderState():get())
export type ObservableNonRenderState = ObservableValue<NonRenderState>

type LoadState = {
	editImage: EditableImage?,
	evfBuffer: buffer?,
}

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,

		observableRenderState: ObservableRenderState,
		observableNonRenderState: ObservableNonRenderState,

		observableLoadState: ObservableValue<LoadState>,
	},
	PostProcessingControllerClass
))

return PostProcessingControllerStatic
