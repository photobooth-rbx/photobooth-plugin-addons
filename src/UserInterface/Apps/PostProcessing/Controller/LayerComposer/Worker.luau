--!native
--!optimize 2

local Types = require(script.Parent.Types)

local function worker(layers: { Types.Layer }, crop: Rect)
	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local composed = buffer.create(cropWidth * cropHeight * 4)

	local bufferByLayer = {}
	for _, layer in layers do
		bufferByLayer[layer] = layer.editImage:ReadPixelsBuffer(crop.Min, cropSize)
	end

	for y = 1, cropHeight do
		for x = 1, cropWidth do
			local blendRGBAs = {}
			for i = #layers, 1, -1 do
				local layer = layers[i]
				local offset = layer.offset

				local dx = x - offset.X
				local dy = y - offset.Y

				if dx > 0 and dx <= cropWidth and dy > 0 and dy <= cropHeight then
					local di = dx + (dy - 1) * cropWidth
					local dj = (di - 1) * 4

					local layerBuffer = bufferByLayer[layer]
					local r = buffer.readu8(layerBuffer, dj + 0) * layer.tintColor.R
					local g = buffer.readu8(layerBuffer, dj + 1) * layer.tintColor.G
					local b = buffer.readu8(layerBuffer, dj + 2) * layer.tintColor.B
					local a = buffer.readu8(layerBuffer, dj + 3) * (1 - layer.transparency)

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

			local i = x + (y - 1) * cropWidth
			local j = (i - 1) * 4

			buffer.writeu8(composed, j + 0, blendedRGBA[1])
			buffer.writeu8(composed, j + 1, blendedRGBA[2])
			buffer.writeu8(composed, j + 2, blendedRGBA[3])
			buffer.writeu8(composed, j + 3, blendedRGBA[4])
		end
	end

	return composed
end

return worker
