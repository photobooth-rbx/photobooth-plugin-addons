local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

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

local function computeInto(source: EditableImage, integralEdit: EditableImage, token: Cancellation.CancelToken)
	local size = source.Size
	local width, height = size.X, size.Y
	local sourceRegion = Rect.new(0, 0, width, height)

	horizontalScheduler:waitForReady()
	local unhookHorizontal = token:onCancel(function()
		horizontalScheduler:cancelWork()
	end)

	local rows = RectSlicer.rows(sourceRegion, horizontalScheduler:getActorCount())
	for _, rowRect in rows do
		horizontalScheduler:schedule(source, 3, rowRect)
	end

	local results, horizontalCancelled = horizontalScheduler:workAsync()
	unhookHorizontal()

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

	local columns = RectSlicer.columns(sourceRegion, verticalScheduler:getActorCount())
	for _, columnRect in columns do
		verticalScheduler:schedule(integralEdit, columnRect)
	end

	local _, verticalCancelled = verticalScheduler:workAsync()
	unhookVertical()
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

--

return IntegralImage
