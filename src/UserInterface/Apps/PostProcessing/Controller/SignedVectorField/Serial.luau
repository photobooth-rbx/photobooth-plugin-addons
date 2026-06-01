--!native
--!optimize 2

local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Timeout = require(pluginRoot.Utilities.Timeout)

local PLUS_ONE = true

local tryYield = Timeout.scriptExhaustionStepper(1 / 60)

local function plantSeeds(img: EditableImage)
	local imgSize = img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local imgBuffer = img:ReadPixelsBuffer(Vector2.zero, imgSize)

	local seedBuffer = buffer.create(imgWidth * imgHeight * 4)

	for y = 1, imgHeight do
		for x = 1, imgWidth do
			tryYield()

			local i = x + (y - 1) * imgWidth
			local j = (i - 1) * 4

			local alpha = buffer.readu8(imgBuffer, j + 3)
			if alpha > 0 then
				buffer.writei32(seedBuffer, i, i)
			else
				buffer.writei32(seedBuffer, i, -i)
			end
		end
	end

	return seedBuffer
end

local function jfa(voronoi: EditableImage, seedbed: buffer)
	local imgSize = voronoi.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	local seedsWrite = buffer.create(buffer.len(seedbed))
	local seedsRead = buffer.create(buffer.len(seedbed))
	buffer.copy(seedsRead, 0, seedbed)

	local maxDim = math.max(imgWidth, imgHeight)
	local nextStep = math.max(1, math.floor(maxDim / 2))

	local passSteps = {}
	while nextStep >= 1 do
		table.insert(passSteps, nextStep)
		nextStep = math.floor(nextStep / 2)
	end

	if PLUS_ONE then
		table.insert(passSteps, 1)
	end

	for _, step in passSteps do
		for y = 1, imgHeight do
			for x = 1, imgWidth do
				tryYield()

				local i = x + (y - 1) * imgWidth
				local j = (i - 1) * 4

				local planted = buffer.readi32(seedbed, j)
				local plantedSign = math.sign(planted)

				local seed = buffer.readi32(seedsRead, j)
				local closestSeed = math.abs(seed)
				if math.sign(seed) == plantedSign then
					closestSeed = 0
				end

				local closestDistSq = math.huge
				if closestSeed > 0 then
					local sy = math.floor((closestSeed - 1) / imgWidth) + 1
					local sx = closestSeed - (sy - 1) * imgWidth
					closestDistSq = (sx - x) ^ 2 + (sy - y) ^ 2
				end

				for oy = -1, 1 do
					local ny = y + oy * step
					if ny < 1 or ny > imgHeight then
						continue
					end

					for ox = -1, 1 do
						if ox == 0 and oy == 0 then
							continue
						end

						local nx = x + ox * step
						if nx < 1 or nx > imgHeight then
							continue
						end

						local k = ((ny - 1) * imgWidth + nx - 1) * 4
						local nPlanted = buffer.readi32(seedbed, k)
						local nSeed = buffer.readi32(seedsRead, k)

						local pixelIndex = 0
						local snx: number, sny: number
						if math.sign(nPlanted) == -plantedSign then
							pixelIndex = math.abs(nPlanted)
							snx, sny = nx, ny
						elseif math.sign(nSeed) == -plantedSign then
							pixelIndex = math.abs(nSeed)
							sny = math.floor((pixelIndex - 1) / imgWidth) + 1
							snx = pixelIndex - (sny - 1) * imgWidth
						end

						if pixelIndex > 0 then
							local distSq = (snx - x) ^ 2 + (sny - y) ^ 2
							if distSq < closestDistSq then
								closestDistSq = distSq
								closestSeed = nSeed
							end
						end
					end
				end

				if closestSeed > 0 then
					buffer.writei32(seedsWrite, j, -plantedSign * closestSeed)
				end
			end
		end

		seedsRead = seedsWrite
	end

	return seedsRead
end

return function(content: Content)
	local voronoiEdit = AssetService:CreateEditableImageAsync(content)

	local seedbed = plantSeeds(voronoiEdit)
	local voronoiBuffer = jfa(voronoiEdit, seedbed)

	voronoiEdit:WritePixelsBuffer(Vector2.zero, voronoiEdit.Size, voronoiBuffer)

	return voronoiEdit
end
