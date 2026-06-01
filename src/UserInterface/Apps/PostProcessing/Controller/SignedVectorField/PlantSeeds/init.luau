local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local scheduler = Parallel.new(ACTOR_COUNT, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function plantSeeds(img: EditableImage, voronoi: EditableImage, regions: { Rect })
	scheduler:waitForReady()

	local imgSize = img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	for _, crop in regions do
		scheduler:schedule(img, crop)
	end

	local offset = 0
	local stitched = buffer.create(imgWidth * imgHeight * 4)

	local results = scheduler:workAsync()
	for i, getCropBuffer in results do
		local cropBuffer = getCropBuffer()
		buffer.copy(stitched, offset, cropBuffer)
		offset = offset + buffer.len(cropBuffer)
	end

	voronoi:WritePixelsBuffer(Vector2.zero, imgSize, stitched)
end

return plantSeeds
