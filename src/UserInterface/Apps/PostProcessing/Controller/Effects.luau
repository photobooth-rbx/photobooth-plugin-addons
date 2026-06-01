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
	if edge1 <= edge0 then
		return if x <= edge0 then 0 else 1
	end
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
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

		for y = 1, imgHeight do
			for x = 1, imgWidth do
				local i = x + (y - 1) * imgWidth
				local j = (i - 1) * 4

				local signedPixelIndex = buffer.readi32(svf, j)
				local pixelIndex = math.abs(signedPixelIndex)
				local sign = math.sign(signedPixelIndex)

				local ny = math.floor((pixelIndex - 1) / imgWidth) + 1
				local nx = pixelIndex - (ny - 1) * imgWidth

				local distanceSq = (nx - x) ^ 2 + (ny - y) ^ 2
				local distance = math.sqrt(distanceSq)
				local signedDistance = distance * sign

				local strokeAlpha = 0
				if properties.thickness > 0 then
					strokeAlpha = 1
						- smoothStep(
							properties.thickness - properties.softness,
							properties.thickness + properties.softness,
							signedDistance
						)
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
		local size = inputs.output.Size
		local b = inputs.output:ReadPixelsBuffer(Vector2.zero, size)
		for i = 1, size.X * size.Y do
			local j = (i - 1) * 4
			buffer.writeu8(b, j + 0, 0)
			buffer.writeu8(b, j + 1, 0)
			buffer.writeu8(b, j + 2, 0)
			buffer.writeu8(b, j + 3, 255)
		end
		inputs.output:WritePixelsBuffer(Vector2.zero, size, b)
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
