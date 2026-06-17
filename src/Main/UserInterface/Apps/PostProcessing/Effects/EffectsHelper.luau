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

-- Outward unit normal at (x, y), estimated as the gradient of the signed distance via
-- central differences. The distance field is smooth and sub-pixel accurate, so its
-- gradient gives a continuous direction (unit length, pointing inside -> outside),
-- unlike the single nearest-seed vector which only resolves ~8 directions near an edge.
-- Neighbour samples are clamped to the image; returns 0, 0 if the gradient is degenerate.
function EffectsHelper.readEdgeNormal(
	svf: buffer,
	width: number,
	height: number,
	x: number,
	y: number
): (number, number)
	local xl = math.max(1, x - 1)
	local xr = math.min(width, x + 1)
	local yt = math.max(1, y - 1)
	local yb = math.min(height, y + 1)

	local gx = EffectsHelper.readSignedDistance(svf, width, xr, y) - EffectsHelper.readSignedDistance(svf, width, xl, y)
	local gy = EffectsHelper.readSignedDistance(svf, width, x, yb) - EffectsHelper.readSignedDistance(svf, width, x, yt)

	local len = math.sqrt(gx * gx + gy * gy)
	if len < 1e-6 then
		return 0, 0
	end
	return gx / len, gy / len
end

-- Reads a packed-u32 summed-area table value at (x, y): the total alpha of the
-- rectangle from (1, 1) to (x, y). Coordinates are clamped to the image bounds, and
-- anything left of / above the first pixel reads as 0, mirroring IntegralImage:read.
function EffectsHelper.readIntegral(integral: buffer, width: number, height: number, x: number, y: number): number
	local cx = math.min(x, width)
	local cy = math.min(y, height)
	if cx > 0 and cy > 0 then
		return buffer.readu32(integral, ((cx - 1) + (cy - 1) * width) * 4)
	end
	return 0
end

-- Average alpha in [0, 1] over the (2r+1)^2 box centred on (x, y), via the summed-area
-- table. Normalised by the number of in-bounds pixels so edges don't darken.
function EffectsHelper.boxAverageAlpha(
	integral: buffer,
	width: number,
	height: number,
	x: number,
	y: number,
	radius: number
): number
	local minX, minY = x - radius, y - radius
	local maxX, maxY = x + radius, y + radius

	local sum = EffectsHelper.readIntegral(integral, width, height, maxX, maxY)
		- EffectsHelper.readIntegral(integral, width, height, minX - 1, maxY)
		- EffectsHelper.readIntegral(integral, width, height, maxX, minY - 1)
		+ EffectsHelper.readIntegral(integral, width, height, minX - 1, minY - 1)

	local cMinX = math.clamp(minX, 1, width)
	local cMaxX = math.clamp(maxX, 1, width)
	local cMinY = math.clamp(minY, 1, height)
	local cMaxY = math.clamp(maxY, 1, height)
	local count = (cMaxX - cMinX + 1) * (cMaxY - cMinY + 1)

	return sum / (count * 255)
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
