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
	local imgSize = inputs.svf.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

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
			local dx = math.floor(x - properties.shadowOffset.X)
			local dy = math.floor(y - properties.shadowOffset.Y)
			if dx > 0 and dx <= imgWidth and dy > 0 and dy <= imgHeight then
				local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, dx, dy)
				local edgeDistance = signedDistance - properties.spread
				shadowAlpha = 1 - EffectsHelper.smoothStep(-properties.blur, properties.blur, edgeDistance)

				if properties.clipped and EffectsHelper.readSignedDistance(svf, imgWidth, x, y) < -1 then
					shadowAlpha = 0
				end
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
