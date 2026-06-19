local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

local Worker = require(script.Worker)

type WorkerAction = typeof(Worker)
export type Properties = Worker.Properties

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

return EffectsRegistry.register("Chromatic Aberration", {
	playerCreated = true,
	renderAboveBase = false,
	create = function()
		local properties: Properties = {
			strength = 6,
			angle = 45,
			offset = Vector2.zero,
			transparency = 0,
			color = Color3.new(1, 1, 1),
		}
		return properties
	end,
	render = function(inputs, properties)
		scheduler:waitForReady()

		local imgSize = inputs.img.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y
		local stitched = buffer.create(imgWidth * imgHeight * 4)

		-- At strength 0 the overlay is left fully transparent, so the base image
		-- shows through untouched (this effect sits above it).
		if properties.strength > 0 then
			local region = Rect.new(0, 0, imgWidth, imgHeight)
			local slices = EffectsHelper.sliceIntoStrips(region, scheduler:getActorCount())
			for _, slice in slices do
				scheduler:schedule(inputs, properties, slice)
			end

			local offset = 0
			local results = scheduler:workAsync()
			for _, getBuffer in results do
				local b = getBuffer()
				buffer.copy(stitched, offset, b)
				offset = offset + buffer.len(b)
			end
		end

		inputs.output:WritePixelsBuffer(Vector2.zero, imgSize, stitched)
	end,
})
