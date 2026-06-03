local EffectsHelper = {}

function EffectsHelper.smoothStep(edge0: number, edge1: number, x: number)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
end

local function getBoxIntersection(x: number, y: number)
	local directionUnit = Vector2.new(x, y).Unit
	local tMaxX = 0.5 / math.abs(directionUnit.X)
	local tMaxY = 0.5 / math.abs(directionUnit.Y)
	local intersection = directionUnit * math.min(tMaxX, tMaxY)
	return intersection.X, intersection.Y
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

return EffectsHelper
