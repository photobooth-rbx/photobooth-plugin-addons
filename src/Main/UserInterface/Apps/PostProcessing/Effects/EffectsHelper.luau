local EffectsHelper = {}

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
	local ox = math.max(0, math.abs(x - nx) - 0.5)
	local oy = math.max(0, math.abs(y - ny) - 0.5)
	local distance = math.sqrt(ox * ox + oy * oy)

	return distance * sign
end

function EffectsHelper.readIntegral(integral: buffer, width: number, height: number, x: number, y: number): number
	local cx = math.min(x, width)
	local cy = math.min(y, height)
	if cx > 0 and cy > 0 then
		return buffer.readu32(integral, ((cx - 1) + (cy - 1) * width) * 4)
	end
	return 0
end

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

-- Like `sliceIntoStrips`, but splits the region into full-height vertical columns. Used by
-- passes that run a per-column scan (e.g. the vertical leg of a separable box blur).
function EffectsHelper.sliceIntoColumns(region: Rect, nSlices: number)
	local width = region.Max.X - region.Min.X
	local height = region.Max.Y - region.Min.Y
	local x0 = region.Min.X
	local y0 = region.Min.Y

	nSlices = math.max(1, math.min(nSlices, width))

	local regions = {}
	local stepX = math.floor(width / nSlices)
	for dx = 1, nSlices do
		local subX0 = x0 + (dx - 1) * stepX
		local subX1 = if dx == nSlices then x0 + width else x0 + dx * stepX
		table.insert(regions, Rect.new(subX0, y0, subX1, y0 + height))
	end

	return regions
end

return EffectsHelper
