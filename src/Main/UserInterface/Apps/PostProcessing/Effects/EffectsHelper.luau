local EffectsHelper = {}

local function getBoxIntersection(x: number, y: number)
	local directionUnit = Vector2.new(x, y).Unit
	local tMaxX = 0.5 / math.abs(directionUnit.X)
	local tMaxY = 0.5 / math.abs(directionUnit.Y)
	local intersection = directionUnit * math.min(tMaxX, tMaxY)
	return intersection.X, intersection.Y
end

function EffectsHelper.smoothStep(edge0: number, edge1: number, x: number)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
end

function EffectsHelper.readSignedDistance(svf: buffer, width: number, x: number, y: number)
	local i = x + (y - 1) * width
	local j = (i - 1) * 4

	local signedPixelIndex = buffer.readi32(svf, j)
	local pixelIndex = math.abs(signedPixelIndex)
	local sign = math.sign(signedPixelIndex)

	local ny = math.floor((pixelIndex - 1) / width) + 1
	local nx = pixelIndex - (ny - 1) * width

	local bx, by = getBoxIntersection(x - nx, y - ny)
	local distanceSq = (x - (nx + bx)) ^ 2 + (y - (ny + by)) ^ 2
	local distance = math.sqrt(distanceSq)
	local signedDistance = distance * sign

	return signedDistance
end

function EffectsHelper.sliceIntoStrips(region: Rect, nSlices: number)
	local width = region.Max.X - region.Min.X
	local height = region.Max.Y - region.Min.Y
	local x0 = region.Min.X
	local y0 = region.Min.Y

	nSlices = math.max(1, math.min(nSlices, height))

	local regions = {}
	local stepY = math.floor(height / nSlices)
	for dy = 1, nSlices do
		local subY0 = y0 + (dy - 1) * stepY
		local subY1 = if dy == nSlices then y0 + height else y0 + dy * stepY
		table.insert(regions, Rect.new(x0, subY0, x0 + width, subY1))
	end

	return regions
end

return EffectsHelper
