--!optimize 2

@native
local function worker(img: EditableImage, channel: number, crop: Rect)
	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local cropBuffer = img:ReadPixelsBuffer(crop.Min, cropSize)

	for y = 1, cropHeight do
		local sum = 0
		for x = 1, cropWidth do
			local i = ((x - 1) + (y - 1) * cropWidth) * 4
			sum = sum + buffer.readu8(cropBuffer, i + channel)
			buffer.writeu32(cropBuffer, i, sum)
		end
	end

	return cropBuffer
end

return worker
