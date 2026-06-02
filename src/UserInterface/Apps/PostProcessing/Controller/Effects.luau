local Effects = {}

export type ImageInputs = {
	base: EditableImage,
	svf: EditableImage,
	output: EditableImage,
}

type EffectRegistration<Properties> = {
	playerCreated: boolean,
	create: () -> Properties,
	render: (ImageInputs, Properties) -> (),
}

local effectByIndex = {}
local effectByKind = {}

local function registerEffect<Properties>(kind: string, registration: EffectRegistration<Properties>)
	local effectEntry = {
		kind = kind,
		index = #effectByIndex + 1,
		playerCreated = registration.playerCreated,

		create = registration.create,
		render = registration.render,
	}

	table.insert(effectByIndex, effectEntry)
	effectByKind[kind] = effectEntry
end

local function smoothStep(edge0: number, edge1: number, x: number)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
end

local function smoothBand(edge0: number, edge1: number, feather: number, x: number)
	local lower = 1 - smoothStep(edge0 - feather, edge0 + feather, x)
	local upper = smoothStep(edge1 - feather, edge1 + feather, x)
	return math.max(lower, upper)
end

local function readSignedDistance(svf: buffer, width: number, x: number, y: number)
	local i = x + (y - 1) * width
	local j = (i - 1) * 4

	local signedPixelIndex = buffer.readi32(svf, j)
	local pixelIndex = math.abs(signedPixelIndex)
	local sign = math.sign(signedPixelIndex)

	local ny = math.floor((pixelIndex - 1) / width) + 1
	local nx = pixelIndex - (ny - 1) * width

	local distanceSq = (nx - x) ^ 2 + (ny - y) ^ 2
	local distance = math.sqrt(distanceSq)
	local signedDistance = distance * sign

	return signedDistance
end

-- Effects

export type BaseImageProperties = {
	transparency: number,
	color: Color3,
}

registerEffect("Base Image", {
	playerCreated = false,
	create = function()
		local properties: BaseImageProperties = {
			transparency = 0,
			color = Color3.new(1, 1, 1),
		}
		return properties
	end,
	render = function(inputs, properties)
		-- do nothing!
	end,
})

export type StrokeProperties = {
	thickness: number,
	softness: number,
	transparency: number,
	color: Color3,
}

registerEffect("Stroke", {
	playerCreated = true,
	create = function()
		local properties: StrokeProperties = {
			thickness = 0,
			softness = 1,
			transparency = 0,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties)
		local imgSize = inputs.output.Size
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
					local signedDistance = readSignedDistance(svf, imgWidth, x, y)
					strokeAlpha = 1 - smoothStep(thickness - softness, thickness + softness, signedDistance)
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

export type DropShadowProperties = {
	blur: number,
	spread: number,
	offset: Vector2,
	transparency: number,
	color: Color3,
}

registerEffect("Drop Shadow", {
	playerCreated = true,
	create = function()
		local properties: DropShadowProperties = {
			transparency = 1,
			color = Color3.new(0, 0, 0),
			offset = Vector2.zero,
			spread = 0,
			blur = 0,
		}
		return properties
	end,
	render = function(inputs, properties)
		local imgSize = inputs.base.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y
		local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)

		local output = buffer.create(imgWidth * imgHeight * 4)
		local maxSpread = properties.spread + properties.blur

		if maxSpread > 0 then
			for y = 1, imgHeight do
				for x = 1, imgWidth do
					local i = x + (y - 1) * imgWidth
					local j = (i - 1) * 4

					local ox = math.floor(x - properties.offset.X)
					local oy = math.floor(y - properties.offset.Y)
					local sx = math.clamp(ox, 1, imgWidth)
					local sy = math.clamp(oy, 1, imgHeight)

					local shadowAlpha = 0
					if math.abs(oy - sy) <= maxSpread and math.abs(ox - sx) <= maxSpread then
						local signedDistance = readSignedDistance(svf, imgWidth, sx, sy)
						local edgeDistance = signedDistance - properties.spread
						shadowAlpha = 1 - smoothStep(-properties.blur, properties.blur, edgeDistance)
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

local playerCreatableKinds = {}
for _, effectEntry in effectByIndex do
	if effectEntry.playerCreated then
		table.insert(playerCreatableKinds, effectEntry.kind)
	end
end
table.freeze(playerCreatableKinds)

-- Public

function Effects.getByKind(kind: string)
	return effectByKind[kind]
end

function Effects.getPlayerCreatableKinds()
	return playerCreatableKinds
end

return Effects
