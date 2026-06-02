local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Image = require(pluginRoot.Utilities.Image)

local IntegralImageStatic = {}

local IntegralImageClass = {}
IntegralImageClass.__index = IntegralImageClass
IntegralImageClass.ClassName = "IntegralImage"

export type IntegralImage = typeof(setmetatable(
	{} :: {
		buffer: buffer,
		width: number,
		height: number,
	},
	IntegralImageClass
))

function IntegralImageStatic.fromRaw(integralBuffer: buffer, width: number, height: number)
	local self = setmetatable({}, IntegralImageClass) :: IntegralImage

	self.buffer = integralBuffer
	self.width = width
	self.height = height

	return self
end

function IntegralImageStatic.fromBuffer(
	imgBuffer: buffer,
	imgSize: Vector2,
	processImgRead: (number, number, number) -> number
)
	local width, height = imgSize.X, imgSize.Y
	local integralBuffer = buffer.create(width * height * 4)

	local function read(x: number, y: number)
		local i = ((x - 1) + (y - 1) * width) * 4
		return buffer.readu32(integralBuffer, i)
	end

	local function write(x: number, y: number, value: number)
		local i = ((x - 1) + (y - 1) * width) * 4
		buffer.writeu32(integralBuffer, i, value)
	end

	local function readImage(x: number, y: number)
		local i = ((x - 1) + (y - 1) * width) * 4
		return processImgRead(buffer.readu32(imgBuffer, i), x, y)
	end

	write(1, 1, readImage(1, 1))

	for x = 2, width do
		write(x, 1, readImage(x, 1) + read(x - 1, 1))
	end

	for y = 2, height do
		write(1, y, readImage(1, y) + read(1, y - 1))
	end

	for x = 2, width do
		for y = 2, height do
			write(x, y, readImage(x, y) + read(x, y - 1) + read(x - 1, y) - read(x - 1, y - 1))
		end
	end

	return IntegralImageStatic.fromRaw(integralBuffer, width, height)
end

function IntegralImageStatic.fromImage(img: Image.Image, processImgRead: (number, number, number) -> number)
	return IntegralImageStatic.fromBuffer(img.buffer, img.size, processImgRead)
end

function IntegralImageClass.read(self: IntegralImage, x: number, y: number)
	local cx = math.min(x, self.width)
	local cy = math.min(y, self.height)
	if cx > 0 and cy > 0 then
		local i = ((cx - 1) + (cy - 1) * self.width) * 4
		return buffer.readu32(self.buffer, i)
	end
	return 0
end

function IntegralImageClass.readArea(self: IntegralImage, minX: number, minY: number, maxX: number, maxY: number)
	-- stylua: ignore
	return self:read(maxX, maxY) 
		- self:read(minX - 1, maxY) 
		- self:read(maxX, minY - 1) 
		+ self:read(minX - 1, minY - 1)
end

function IntegralImageClass.readRadius(self: IntegralImage, x: number, y: number, radius: number)
	return self:readArea(x - radius, y - radius, x + radius, y + radius)
end

function IntegralImageClass.getNPixelsInRadius(self: IntegralImage, x: number, y: number, radius: number)
	local minX = math.clamp(x - radius, 1, self.width)
	local maxX = math.clamp(x + radius, 1, self.width)
	local minY = math.clamp(y - radius, 1, self.height)
	local maxY = math.clamp(y + radius, 1, self.height)
	return (maxX - minX + 1) * (maxY - minY + 1)
end

return IntegralImageStatic
