--!optimize 2

@native
local function worker(img: EditableImage, crop: Rect)
	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local cropBuffer = img:ReadPixelsBuffer(crop.Min, cropSize)

	for x = 1, cropWidth do
		local sum = 0
		for y = 1, cropHeight do
			local i = ((x - 1) + (y - 1) * cropWidth) * 4
			sum = sum + buffer.readu32(cropBuffer, i)
			buffer.writeu32(cropBuffer, i, sum)
		end
	end

	task.synchronize()

	img:WritePixelsBuffer(crop.Min, cropSize, cropBuffer)
end

return worker
