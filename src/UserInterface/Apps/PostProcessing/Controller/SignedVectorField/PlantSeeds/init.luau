local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local Trove = require(pluginRoot.Packages.Trove)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local function plantSeeds(img: EditableImage, voronoi: EditableImage, regions: { Rect }, cancelTrove: Trove.Trove)
	local scheduler = Parallel.new(ACTOR_COUNT, {
		script = script.Worker,
		typecast = (nil :: any) :: WorkerAction,
	})

	cancelTrove:Add(function()
		scheduler:cancelWork()
		scheduler:Destroy()
	end)

	scheduler:waitForReady()

	local imgSize = img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	for _, crop in regions do
		scheduler:schedule(img, crop)
	end

	local offset = 0
	local stitched = buffer.create(imgWidth * imgHeight * 4)

	local results, workCancelled = scheduler:workAsync()
	if not workCancelled then
		for _i, getBuffer in results do
			local cropBuffer = getBuffer()
			buffer.copy(stitched, offset, cropBuffer)
			offset = offset + buffer.len(cropBuffer)
		end
	end

	voronoi:WritePixelsBuffer(Vector2.zero, imgSize, stitched)

	return workCancelled
end

return plantSeeds
