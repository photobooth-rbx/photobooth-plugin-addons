--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	blur: number,
	spread: number,
	clipped: boolean,
	shadowOffset: Vector2,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

@native
local function worker(inputs: EffectsRegistry.ImageInputs, properties: Properties, crop: Rect)
	local imgSize = inputs.integral.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local integral = inputs.integral:ReadPixelsBuffer(Vector2.zero, imgSize)
	local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)
	local composed = buffer.create(cropWidth * cropHeight * 4)

	-- `blur` is the soft band half-width (in px) and `spread` grows (+) or shrinks (-)
	-- the shadow. We size the sampling box to reach `blur + |spread|` past the edge, then
	-- place the coverage band so its midpoint sits at distance `spread` from the subject
	-- edge. Over a straight edge the box average is coverage = 0.5 - dist / (2 * radius),
	-- so the band maps distances [spread - blur, spread + blur] -> alpha [1, 0]. This makes
	-- spread a true pixel offset while keeping the empty region (coverage 0) transparent.
	local blur = math.max(0, properties.blur)
	local spread = properties.spread
	local radius = math.max(1, math.floor(blur + math.abs(spread) + 0.5))

	local loEdge = math.max(0, 0.5 - (spread + blur) / (2 * radius))
	local hiEdge = math.min(1, 0.5 - (spread - blur) / (2 * radius))
	-- Guard against a zero-width band (e.g. blur ~ 0) so smoothStep stays well-defined.
	hiEdge = math.max(hiEdge, loEdge + 1e-4)

	local offsetX = math.floor(properties.shadowOffset.X)
	local offsetY = math.floor(properties.shadowOffset.Y)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local coverage =
				EffectsHelper.boxAverageAlpha(integral, imgWidth, imgHeight, x - offsetX, y - offsetY, radius)
			local shadowAlpha = EffectsHelper.smoothStep(loEdge, hiEdge, coverage)

			-- Keep the shadow out of the subject's own footprint.
			if properties.clipped and EffectsHelper.readSignedDistance(svf, imgWidth, x, y) < -1 then
				shadowAlpha = 0
			end

			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * shadowAlpha)
		end
	end

	return composed
end

return worker
