local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

type HorizontalAction = typeof(require(script.HorizontalWorker))
type VerticalAction = typeof(require(script.VerticalWorker))

export type Properties = {
	blur: number,
	spread: number,
	clipped: boolean,
	shadowOffset: Vector2,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

-- The shadow is a separable box blur of the SDF-dilated silhouette: a horizontal pass
-- (dilate + horizontal mean) into the scratch image, then a vertical pass (vertical mean +
-- offset + clip) into the output.
local horizontalScheduler = Parallel.new(32, {
	script = script.HorizontalWorker,
	typecast = (nil :: any) :: HorizontalAction,
})

local verticalScheduler = Parallel.new(32, {
	script = script.VerticalWorker,
	typecast = (nil :: any) :: VerticalAction,
})

return EffectsRegistry.register("Drop Shadow", {
	playerCreated = true,
	create = function()
		local properties: Properties = {
			blur = 4,
			spread = 0,
			clipped = false,
			shadowOffset = Vector2.new(4, 6),
			transparency = 0.4,
			offset = Vector2.zero,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties)
		horizontalScheduler:waitForReady()
		verticalScheduler:waitForReady()

		local imgSize = inputs.scratch.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y
		local region = Rect.new(0, 0, imgWidth, imgHeight)

		-- Pass 1: dilate + horizontal mean -> scratch (stitched from contiguous row strips).
		local rowStrips = EffectsHelper.sliceIntoStrips(region, horizontalScheduler:getActorCount())
		for _, strip in rowStrips do
			horizontalScheduler:schedule(inputs.svf, properties.spread, properties.blur, strip)
		end

		local stitched = buffer.create(imgWidth * imgHeight * 4)
		local offset = 0
		for _, getBuffer in horizontalScheduler:workAsync() do
			local b = getBuffer()
			buffer.copy(stitched, offset, b)
			offset = offset + buffer.len(b)
		end
		inputs.scratch:WritePixelsBuffer(Vector2.zero, imgSize, stitched)

		-- Pass 2: vertical mean (+offset, clip) -> output. Column strips don't stitch
		-- contiguously, so each result is blitted into the output at its own x-origin.
		local offX = math.floor(properties.shadowOffset.X)
		local offY = math.floor(properties.shadowOffset.Y)
		local colStrips = EffectsHelper.sliceIntoColumns(region, verticalScheduler:getActorCount())
		for _, strip in colStrips do
			verticalScheduler:schedule(
				inputs.scratch,
				inputs.svf,
				properties.blur,
				offX,
				offY,
				properties.clipped,
				strip
			)
		end

		for i, getBuffer in verticalScheduler:workAsync() do
			local strip = colStrips[i]
			local stripMin = strip.Min
			local stripWidth = strip.Max.X - strip.Min.X
			inputs.output:WritePixelsBuffer(Vector2.new(stripMin.X, 0), Vector2.new(stripWidth, imgHeight), getBuffer())
		end
	end,
})
