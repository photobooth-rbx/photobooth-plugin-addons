local AssetService = game:GetService("AssetService")
local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

type HorizontalWorker = typeof(require(script.HorizontalWorker))

local horizontalScheduler = Parallel.new(32, {
	script = script.HorizontalWorker,
	typecast = (nil :: any) :: HorizontalWorker,
})

type VerticalWorker = typeof(require(script.VerticalWorker))

local verticalScheduler = Parallel.new(32, {
	script = script.VerticalWorker,
	typecast = (nil :: any) :: VerticalWorker,
})

local IntegralImageStatic = {}

local IntegralImageClass = {}
IntegralImageClass.__index = IntegralImageClass
IntegralImageClass.ClassName = "IntegralImage"

export type IntegralImage = typeof(setmetatable(
	{} :: {
		buffer: buffer,
		width: number,
		height: number,
	},
	IntegralImageClass
))

function IntegralImageStatic.fromRaw(integralBuffer: buffer, width: number, height: number)
	local self = setmetatable({}, IntegralImageClass) :: IntegralImage

	self.buffer = integralBuffer
	self.width = width
	self.height = height

	return self
end

local function sliceIntoStrips(size: Vector2, xSlices: number, ySlices: number)
	local strips = {}
	local width, height = size.X, size.Y

	xSlices = math.max(1, math.min(xSlices, width))
	ySlices = math.max(1, math.min(ySlices, height))

	local stepY = math.floor(height / ySlices)
	local stepX = math.floor(width / xSlices)
	for dy = 1, ySlices do
		for dx = 1, xSlices do
			local subY0 = (dy - 1) * stepY
			local subY1 = if dy == ySlices then height else dy * stepY

			local subX0 = (dx - 1) * stepX
			local subX1 = if dx == xSlices then width else dx * stepX

			table.insert(strips, Rect.new(subX0, subY0, subX1, subY1))
		end
	end

	return strips
end

function IntegralImageStatic.fromEditImage(editImage: EditableImage)
	local size = editImage.Size
	local width, height = size.X, size.Y

	horizontalScheduler:waitForReady()

	local horizontalStrips = sliceIntoStrips(size, 1, horizontalScheduler:getActorCount())
	for _, strip in horizontalStrips do
		horizontalScheduler:schedule(editImage, 3, strip)
	end

	local results = horizontalScheduler:workAsync()

	local offset = 0
	local stitched = buffer.create(width * height * 4)
	for _, unpackBuffer in results do
		local b = unpackBuffer()
		buffer.copy(stitched, offset, b)
		offset = offset + buffer.len(b)
	end

	local hImg = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
	hImg:WritePixelsBuffer(Vector2.zero, size, stitched)

	verticalScheduler:waitForReady()

	local verticalStrips = sliceIntoStrips(size, verticalScheduler:getActorCount(), 1)
	for _, strip in verticalStrips do
		verticalScheduler:schedule(hImg, strip)
	end

	verticalScheduler:workAsync()

	local integralBuffer = hImg:ReadPixelsBuffer(Vector2.zero, size)
	hImg:Destroy()

	return IntegralImageStatic.fromRaw(integralBuffer, width, height)
end

function IntegralImageClass.read(self: IntegralImage, x: number, y: number)
	local cx = math.min(x, self.width)
	local cy = math.min(y, self.height)
	if cx > 0 and cy > 0 then
		local i = ((cx - 1) + (cy - 1) * self.width) * 4
		return buffer.readu32(self.buffer, i)
	end
	return 0
end

function IntegralImageClass.readArea(self: IntegralImage, minX: number, minY: number, maxX: number, maxY: number)
	-- stylua: ignore
	return self:read(maxX, maxY) 
		- self:read(minX - 1, maxY) 
		- self:read(maxX, minY - 1) 
		+ self:read(minX - 1, minY - 1)
end

function IntegralImageClass.readRadius(self: IntegralImage, x: number, y: number, radius: number)
	return self:readArea(x - radius, y - radius, x + radius, y + radius)
end

function IntegralImageClass.getNPixelsInRadius(self: IntegralImage, x: number, y: number, radius: number)
	local minX = math.clamp(x - radius, 1, self.width)
	local maxX = math.clamp(x + radius, 1, self.width)
	local minY = math.clamp(y - radius, 1, self.height)
	local maxY = math.clamp(y + radius, 1, self.height)
	return (maxX - minX + 1) * (maxY - minY + 1)
end

function IntegralImageClass.Destroy(_self: IntegralImage) end

return IntegralImageStatic
