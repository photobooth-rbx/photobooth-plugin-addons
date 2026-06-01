--!strict

local AssetService = game:GetService("AssetService")

local ACTOR_COUNT = 32
script:SetAttribute("ActorCount", ACTOR_COUNT)

local SignedVectorField = {}

local PlantSeeds = require(script.PlantSeeds)
local JFAPasses = require(script.JFAPasses)

local function sliceIntoStrips(region: Rect, nSlices: number)
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

function SignedVectorField.generateAsync(content: Content)
	local imgEdit = AssetService:CreateEditableImageAsync(content)
	local voronoiEdit = AssetService:CreateEditableImageAsync(content)

	local success, err: string? = pcall(function()
		local imgSize = imgEdit.Size
		local fullRegion = Rect.new(0, 0, imgSize.X, imgSize.Y)
		local plantRegions = sliceIntoStrips(fullRegion, ACTOR_COUNT)

		PlantSeeds(imgEdit, voronoiEdit, plantRegions)
		JFAPasses(voronoiEdit, plantRegions)
	end)

	imgEdit:Destroy()

	if not success and err then
		error(err, 0)
	end

	return voronoiEdit
end

return SignedVectorField
