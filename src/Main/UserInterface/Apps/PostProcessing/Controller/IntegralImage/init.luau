local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local Cancellation = require(pluginRoot.Utilities.Cancellation)

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
local IntegralImagePrivate = {}

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

function IntegralImageStatic.generate(content: Content)
	return Cancellation.new(function(token)
		local sourceEdit = AssetService:CreateEditableImageAsync(content)
		local unhookSource = token:onCancel(function()
			sourceEdit:Destroy()
		end)

		local integralEdit = AssetService:CreateEditableImageAsync(content)
		local unhookIntegral = token:onCancel(function()
			integralEdit:Destroy()
		end)

		local success, err: string? = pcall(function()
			IntegralImagePrivate.computeInto(sourceEdit, integralEdit, token)
		end)

		unhookSource()
		sourceEdit:Destroy()

		if not success and err and not token:isCancelled() then
			error(err, 0)
		end

		unhookIntegral()
		return integralEdit
	end)
end

function IntegralImageStatic.fromEditImage(integralEdit: EditableImage)
	local self = setmetatable({}, IntegralImageClass) :: IntegralImage

	local size = integralEdit.Size
	local integralBuffer = integralEdit:ReadPixelsBuffer(Vector2.zero, size)

	self.buffer = integralBuffer
	self.width = size.X
	self.height = size.Y

	return self
end

-- Private

function IntegralImagePrivate.sliceIntoStrips(size: Vector2, xSlices: number, ySlices: number)
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

function IntegralImagePrivate.computeInto(
	source: EditableImage,
	integralEdit: EditableImage,
	token: Cancellation.CancelToken?
)
	local size = source.Size
	local width, height = size.X, size.Y

	horizontalScheduler:waitForReady()
	local unhookHorizontal = token and token:onCancel(function()
		horizontalScheduler:cancelWork()
	end)

	local horizontalStrips = IntegralImagePrivate.sliceIntoStrips(size, 1, horizontalScheduler:getActorCount())
	for _, strip in horizontalStrips do
		horizontalScheduler:schedule(source, 3, strip)
	end

	local results, horizontalCancelled = horizontalScheduler:workAsync()
	if unhookHorizontal then
		unhookHorizontal()
	end
	if horizontalCancelled then
		return false
	end

	local offset = 0
	local stitched = buffer.create(width * height * 4)
	for _, unpackBuffer in results do
		local b = unpackBuffer()
		buffer.copy(stitched, offset, b)
		offset = offset + buffer.len(b)
	end
	integralEdit:WritePixelsBuffer(Vector2.zero, size, stitched)

	verticalScheduler:waitForReady()
	local unhookVertical = token and token:onCancel(function()
		verticalScheduler:cancelWork()
	end)

	local verticalStrips = IntegralImagePrivate.sliceIntoStrips(size, verticalScheduler:getActorCount(), 1)
	for _, strip in verticalStrips do
		verticalScheduler:schedule(integralEdit, strip)
	end

	local _, verticalCancelled = verticalScheduler:workAsync()
	if unhookVertical then
		unhookVertical()
	end
	if verticalCancelled then
		return false
	end

	return true
end

-- Methods

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

--

return IntegralImageStatic
