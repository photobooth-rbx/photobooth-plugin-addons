local AnimationManagerStatic = {}

local AnimationManagerClass = {}
AnimationManagerClass.__index = AnimationManagerClass
AnimationManagerClass.ClassName = "AnimationManager"

export type AnimationManager = typeof(setmetatable({} :: {}, AnimationManagerClass))

function AnimationManagerStatic.new(model: Model)
	local self = setmetatable({}, AnimationManagerClass) :: AnimationManager

	return self
end

return AnimationManagerStatic
