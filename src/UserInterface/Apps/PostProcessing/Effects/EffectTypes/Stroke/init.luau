local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	thickness: number,
	softness: number,
	clipped: boolean,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

return EffectsRegistry.register("Stroke", {
	playerCreated = true,
	create = function()
		local properties: Properties = {
			thickness = 5,
			softness = 1,
			clipped = false,
			transparency = 0,
			offset = Vector2.zero,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties)
		print("wrf?")

		local imgSize = inputs.img.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y
		local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)
		local output = buffer.create(imgWidth * imgHeight * 4)

		local softness = properties.softness
		local thickness = properties.thickness

		for y = 1, imgHeight do
			for x = 1, imgWidth do
				local i = x + (y - 1) * imgWidth
				local j = (i - 1) * 4

				local strokeAlpha = 0
				if thickness > 0 then
					local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)
					strokeAlpha = 1
						- EffectsHelper.smoothStep(thickness - softness, thickness + softness, signedDistance)

					if properties.clipped and signedDistance < -1 then
						strokeAlpha = 0
					end
				end

				buffer.writeu8(output, j + 0, 255)
				buffer.writeu8(output, j + 1, 255)
				buffer.writeu8(output, j + 2, 255)
				buffer.writeu8(output, j + 3, 255 * strokeAlpha)
			end
		end

		inputs.output:WritePixelsBuffer(Vector2.zero, imgSize, output)
	end,
})
