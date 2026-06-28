local RectSlicer = {}

function RectSlicer.chunks(region: Rect, xSlices: number, ySlices: number)
	local width = region.Max.X - region.Min.X
	local height = region.Max.Y - region.Min.Y
	local x0 = region.Min.X
	local y0 = region.Min.Y

	xSlices = math.max(1, math.min(xSlices, width))
	ySlices = math.max(1, math.min(ySlices, height))

	local chunks = {}
	local stepY = math.floor(height / ySlices)
	local stepX = math.floor(width / xSlices)
	for dy = 1, ySlices do
		for dx = 1, xSlices do
			local subY0 = (dy - 1) * stepY
			local subY1 = if dy == ySlices then height else dy * stepY

			local subX0 = (dx - 1) * stepX
			local subX1 = if dx == xSlices then width else dx * stepX

			table.insert(chunks, Rect.new(x0 + subX0, y0 + subY0, x0 + subX1, y0 + subY1))
		end
	end

	return chunks
end

function RectSlicer.rows(region: Rect, nRows: number)
	return RectSlicer.chunks(region, 1, nRows)
end

function RectSlicer.columns(region: Rect, nColumns: number)
	return RectSlicer.chunks(region, nColumns, 1)
end

return RectSlicer
