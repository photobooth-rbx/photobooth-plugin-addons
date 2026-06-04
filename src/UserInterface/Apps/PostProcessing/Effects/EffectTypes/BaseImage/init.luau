local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)

export type Properties = {
	transparency: number,
	offset: Vector2,
	color: Color3,
}

return EffectsRegistry.register("Base Image", {
	playerCreated = false,
	create = function()
		local properties: Properties = {
			transparency = 0,
			offset = Vector2.zero,
			color = Color3.new(1, 1, 1),
		}
		return properties
	end,
	render = function(_inputs, _properties)
		-- do nothing!
	end,
})
