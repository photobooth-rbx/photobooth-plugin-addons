local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local Cancellation = require(pluginRoot.Utilities.Cancellation)

local IntegralImage = {}

-- Private

type HorizontalWorker = typeof(require(script.HorizontalWorker))
type VerticalWorker = typeof(require(script.VerticalWorker))

local horizontalScheduler = Parallel.new(32, {
	script = script.HorizontalWorker,
	typecast = (nil :: any) :: HorizontalWorker,
})

local verticalScheduler = Parallel.new(32, {
	script = script.VerticalWorker,
	typecast = (nil :: any) :: VerticalWorker,
})

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

local function computeInto(source: EditableImage, integralEdit: EditableImage, token: Cancellation.CancelToken?)
	local size = source.Size
	local width, height = size.X, size.Y

	horizontalScheduler:waitForReady()
	local unhookHorizontal = token and token:onCancel(function()
		horizontalScheduler:cancelWork()
	end)

	local horizontalStrips = sliceIntoStrips(size, 1, horizontalScheduler:getActorCount())
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

	local verticalStrips = sliceIntoStrips(size, verticalScheduler:getActorCount(), 1)
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

-- Public

function IntegralImage.generate(content: Content)
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
			computeInto(sourceEdit, integralEdit, token)
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

-- Private

--

return IntegralImage
