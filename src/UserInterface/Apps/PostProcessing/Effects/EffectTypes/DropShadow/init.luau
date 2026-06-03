local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	blur: number,
	spread: number,
	clipped: boolean,
	shadowOffset: Vector2,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

return EffectsRegistry.register("Drop Shadow", {
	playerCreated = true,
	create = function()
		local properties: Properties = {
			blur = 10,
			spread = 10,
			clipped = false,
			shadowOffset = Vector2.new(20, 20),
			transparency = 0.6,
			offset = Vector2.zero,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties)
		local imgSize = inputs.img.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y

		local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)
		local output = buffer.create(imgWidth * imgHeight * 4)
		local maxSpread = properties.spread + properties.blur

		if maxSpread > 0 then
			for y = 1, imgHeight do
				for x = 1, imgWidth do
					local i = x + (y - 1) * imgWidth
					local j = (i - 1) * 4

					local shadowAlpha = 0
					local dx = math.floor(x - properties.shadowOffset.X)
					local dy = math.floor(y - properties.shadowOffset.Y)
					if dx > 0 and dx <= imgWidth and dy > 0 and dy <= imgHeight then
						local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, dx, dy)
						local edgeDistance = signedDistance - properties.spread
						shadowAlpha = 1 - EffectsHelper.smoothStep(-properties.blur, properties.blur, edgeDistance)

						if properties.clipped and EffectsHelper.readSignedDistance(svf, imgWidth, x, y) < -1 then
							shadowAlpha = 0
						end
					end

					buffer.writeu8(output, j + 0, 255)
					buffer.writeu8(output, j + 1, 255)
					buffer.writeu8(output, j + 2, 255)

					buffer.writeu8(output, j + 3, 255 * shadowAlpha)
				end
			end
		end

		inputs.output:WritePixelsBuffer(Vector2.zero, imgSize, output)
	end,
})
