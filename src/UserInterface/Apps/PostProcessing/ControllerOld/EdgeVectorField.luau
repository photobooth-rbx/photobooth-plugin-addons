local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityQueue = require(pluginRoot.Packages.PriorityQueue)
local Image = require(pluginRoot.Utilities.Image)

local IntegralImage = require(script.Parent.IntegralImage)

local EdgeVectorField = {}

local I16_MAX = 32767

type PQ = PriorityQueue.PriorityQueue<{
	index: number,
	offset: Vector2,
}>

function EdgeVectorField.generate(img: Image.Image, tryYield: () -> ())
	local width = img:GetWidth()
	local height = img:GetHeight()

	assert(width <= I16_MAX, "Image width is too large to store edge vector field offsets.")
	assert(height <= I16_MAX, "Image height is too large to store edge vector field offsets.")

	local alphaIntImg = IntegralImage.fromImage(img, function(u32)
		tryYield()
		return bit32.extract(u32, 24, 8)
	end)

	local closed = table.create(width * height, false)
	local offsets = table.create(width * height, Vector2.new(math.huge, math.huge))
	local pqA: PQ = PriorityQueue.min()
	local pqB: PQ = PriorityQueue.min()

	for y = 1, height do
		for x = 1, width do
			tryYield()

			local i = img:GetPixelIndex(x, y)
			local _, _, _, alpha = img:GetRGBA255(i)
			local alphaSum = alphaIntImg:ReadRadius(x, y, 1)
			local nPixelsInRadius = alphaIntImg:GetNPixelsInRadius(x, y, 1)

			if alpha > 0 and alphaSum < nPixelsInRadius * 255 then
				for _, ni in img:IterateNeighbors(i) do
					local nx, ny = img:GetXYFromPixelIndex(ni)
					local _, _, _, nAlpha = img:GetRGBA255(ni)

					if nAlpha == 0 then
						local delta = Vector2.new(x - nx, y - ny) / 2
						local distance = delta.Magnitude

						pqA:insert(distance, {
							index = ni,
							offset = delta,
						})

						pqB:insert(distance, {
							index = i,
							offset = -delta,
						})
					end
				end
			end
		end
	end

	local function expand(pq: PQ, alphaSign: number)
		while not pq:isEmpty() do
			local current = pq:pop()
			if current and not closed[current.index] then
				tryYield()

				closed[current.index] = true
				offsets[current.index] = current.offset

				local x, y = img:GetXYFromPixelIndex(current.index)
				for _, ni in img:IterateNeighbors(current.index) do
					if not closed[ni] then
						local nx, ny = img:GetXYFromPixelIndex(ni)
						local _, _, _, nAlpha = img:GetRGBA255(ni)

						if math.sign(nAlpha) == alphaSign then
							local delta = Vector2.new(x - nx, y - ny)
							local offset = delta + current.offset

							pq:insert(offset.Magnitude, {
								offset = offset,
								index = ni,
							})
						end
					end
				end
			end
		end
	end

	expand(pqA, 0)
	expand(pqB, 1)

	local evfBuffer = buffer.create(width * height * 4)
	for i = 1, #offsets do
		local j = (i - 1) * 4

		-- all offsets are some factor of 0.5 so if we multiply by 2 we always get integers
		-- which we can then safely store as i16s. just remember to divide by two when you read them!
		local offset2 = offsets[i] * 2
		buffer.writei16(evfBuffer, j + 0, offset2.X)
		buffer.writei16(evfBuffer, j + 2, offset2.Y)
	end

	return evfBuffer
end

return EdgeVectorField
