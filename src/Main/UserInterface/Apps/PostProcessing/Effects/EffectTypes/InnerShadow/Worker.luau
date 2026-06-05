--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

-- How far past the silhouette the shadow still counts as "inside", plus how softly it
-- fades out beyond that. The margin guarantees the antialiased fringe is fully covered
-- instead of leaving a bright rim at the very edge.
local EDGE_MARGIN = 1
local EDGE_FEATHER = 1

export type Properties = {
	blur: number,
	spread: number,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

@native
local function worker(inputs: EffectsRegistry.ImageInputs, properties: Properties, crop: Rect)
	local imgSize = inputs.svf.Size
	local imgWidth, _imgHeight = imgSize.X, imgSize.Y

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)
	local composed = buffer.create(cropWidth * cropHeight * 4)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local shadowAlpha = 0

			local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)

			-- Clip to the subject, but extend EDGE_MARGIN past the silhouette so the
			-- antialiased fringe is fully covered with no bright rim at the edge.
			local insideMask = 1 - EffectsHelper.smoothStep(EDGE_MARGIN, EDGE_MARGIN + EDGE_FEATHER, signedDistance)
			if insideMask > 0 then
				-- Shadow is strongest at the edge and fades inward across the blur band.
				local edgeDistance = signedDistance + properties.spread
				shadowAlpha = EffectsHelper.smoothStep(-properties.blur, properties.blur, edgeDistance) * insideMask
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
