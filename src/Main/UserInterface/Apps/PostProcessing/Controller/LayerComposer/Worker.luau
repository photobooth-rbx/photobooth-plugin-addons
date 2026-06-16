--!optimize 2

local Types = require(script.Parent.Types)

-- `crop` is the horizontal strip of the output this actor is responsible for, but
-- layer offsets can sample pixels from anywhere in the image (a vertical offset
-- pulls from a neighbouring strip), so each layer is read in full and sampled by
-- global coordinates.
@native
local function worker(layers: { Types.Layer }, crop: Rect, fullSize: Vector2)
	local cropMin = crop.Min
	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local fullWidth, fullHeight = fullSize.X, fullSize.Y
	local composed = buffer.create(cropWidth * cropHeight * 4)

	local bufferByLayer = {}
	for _, layer in layers do
		bufferByLayer[layer] = layer.editImage:ReadPixelsBuffer(Vector2.zero, fullSize)
	end

	for y = 0, cropHeight - 1 do
		local gy = cropMin.Y + y
		for x = 0, cropWidth - 1 do
			local gx = cropMin.X + x

			local blendRGBAs = {}
			for i = #layers, 1, -1 do
				local layer = layers[i]
				local sx = gx - math.floor(layer.offset.X)
				local sy = gy - math.floor(layer.offset.Y)

				if sx >= 0 and sx < fullWidth and sy >= 0 and sy < fullHeight then
					local sj = (sx + sy * fullWidth) * 4

					local layerBuffer = bufferByLayer[layer]
					local r = buffer.readu8(layerBuffer, sj + 0) * layer.tintColor.R
					local g = buffer.readu8(layerBuffer, sj + 1) * layer.tintColor.G
					local b = buffer.readu8(layerBuffer, sj + 2) * layer.tintColor.B
					local a = buffer.readu8(layerBuffer, sj + 3) * (1 - layer.transparency)

					table.insert(blendRGBAs, { r, g, b, a })
				end
			end

			local blendedRGBA = { 0, 0, 0, 0 }
			for _, rgba in blendRGBAs do
				local aAlpha = rgba[4] / 255
				local bAlpha = blendedRGBA[4] / 255

				local outAlpha = aAlpha + bAlpha * (1 - aAlpha)
				local newRGBA = { 0, 0, 0, outAlpha * 255 }

				if outAlpha > 0 then
					for j = 1, 3 do
						newRGBA[j] = (rgba[j] * aAlpha + blendedRGBA[j] * bAlpha * (1 - aAlpha)) / outAlpha
					end
				end

				blendedRGBA = newRGBA
			end

			local oj = (x + y * cropWidth) * 4

			buffer.writeu8(composed, oj + 0, blendedRGBA[1])
			buffer.writeu8(composed, oj + 1, blendedRGBA[2])
			buffer.writeu8(composed, oj + 2, blendedRGBA[3])
			buffer.writeu8(composed, oj + 3, blendedRGBA[4])
		end
	end

	return composed
end

return worker
