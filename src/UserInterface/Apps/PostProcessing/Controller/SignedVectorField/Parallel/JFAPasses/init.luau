--!strict

local AssetService = game:GetService("AssetService") :: AssetService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local PLUS_ONE = assert(script.Parent:GetAttribute("PlusOne") :: boolean?)
local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local scheduler = Parallel.new(ACTOR_COUNT, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function jfaPasses(voronoi: EditableImage, regions: { Rect })
	scheduler:waitForReady()

	local voronoiSize = voronoi.Size
	local voronoiWidth, voronoiHeight = voronoiSize.X, voronoiSize.Y

	local seedbed = AssetService:CreateEditableImageAsync(Content.fromObject(voronoi))

	local maxDim = math.max(voronoiWidth, voronoiHeight)
	local nextStep = math.max(1, math.floor(maxDim / 2))

	local passSteps = {}
	while nextStep >= 1 do
		table.insert(passSteps, nextStep)
		nextStep = math.floor(nextStep / 2)
	end

	if PLUS_ONE then
		table.insert(passSteps, 1)
	end

	local stitched = buffer.create(voronoiWidth * voronoiHeight * 4)

	for _, step in passSteps do
		for _, crop in regions do
			scheduler:schedule(seedbed, voronoi, crop, step)
		end

		local offset = 0
		local results = scheduler:workAsync()
		for i, getCropBuffer in results do
			local cropBuffer = getCropBuffer()
			buffer.copy(stitched, offset, cropBuffer)
			offset = offset + buffer.len(cropBuffer)
		end

		voronoi:WritePixelsBuffer(Vector2.zero, voronoiSize, stitched)
	end

	seedbed:Destroy()

	return #passSteps
end

return jfaPasses
