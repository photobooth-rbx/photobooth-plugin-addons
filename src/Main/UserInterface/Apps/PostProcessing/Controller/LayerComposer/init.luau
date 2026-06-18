local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local Types = require(script.Types)

local LayerComposer = {}

export type Layer = Types.Layer
export type Adjustment = Types.Adjustment

type WorkerAction = typeof(require(script.Worker))

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function sliceIntoStrips(region: Rect, nSlices: number)
	local width = region.Max.X - region.Min.X
	local height = region.Max.Y - region.Min.Y
	local x0 = region.Min.X
	local y0 = region.Min.Y

	nSlices = math.max(1, math.min(nSlices, height))

	local regions = {}
	local stepY = math.floor(height / nSlices)
	for dy = 1, nSlices do
		local subY0 = y0 + (dy - 1) * stepY
		local subY1 = if dy == nSlices then y0 + height else y0 + dy * stepY
		table.insert(regions, Rect.new(x0, subY0, x0 + width, subY1))
	end

	return regions
end

function LayerComposer.composeAsync(editImage: EditableImage, layers: { Layer }, adjustment: Adjustment?)
	scheduler:waitForReady()

	local imgSize = editImage.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local fullRegion = Rect.new(0, 0, imgWidth, imgHeight)
	local strips = sliceIntoStrips(fullRegion, scheduler:getActorCount())

	for _, strip in strips do
		scheduler:schedule(layers, strip, imgSize, adjustment)
	end

	local results = scheduler:workAsync()

	local offset = 0
	local stitched = buffer.create(imgWidth * imgHeight * 4)
	for _, getBuffer in results do
		local b = getBuffer()
		buffer.copy(stitched, offset, b)
		offset = offset + buffer.len(b)
	end

	local composedEdit = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
	composedEdit:WritePixelsBuffer(Vector2.zero, imgSize, stitched)

	return composedEdit
end

return LayerComposer
