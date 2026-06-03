local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local PLUS_ONE = true
local ACTOR_COUNT = 32

script:SetAttribute("PlusOne", PLUS_ONE)
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

function SignedVectorField.generator(content: Content)
	local isComplete = false
	local wasCancelled = false
	local cancelTrove = Trove.new()
	local function cancel()
		if not isComplete then
			wasCancelled = true
			cancelTrove:Destroy()
		end
	end

	local function generateAsync()
		local imgEdit = AssetService:CreateEditableImageAsync(content)
		local voronoiEdit = AssetService:CreateEditableImageAsync(content)

		local success, err = pcall(function()
			local imgSize = imgEdit.Size
			local fullRegion = Rect.new(0, 0, imgSize.X, imgSize.Y)
			local plantRegions = sliceIntoStrips(fullRegion, ACTOR_COUNT)

			local cancelled = PlantSeeds(imgEdit, voronoiEdit, plantRegions, cancelTrove)
			if not cancelled then
				JFAPasses(voronoiEdit, plantRegions, cancelTrove)
			end
		end)

		isComplete = true
		imgEdit:Destroy()

		if not success and err then
			error(err, 0)
		end

		return voronoiEdit, wasCancelled
	end

	return {
		generateAsync = generateAsync,
		cancel = cancel,
	}
end

return SignedVectorField
