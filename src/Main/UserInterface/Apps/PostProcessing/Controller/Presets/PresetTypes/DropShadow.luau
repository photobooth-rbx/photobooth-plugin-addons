local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("dropShadow", {
	name = "Drop Shadow",
	layers = {
		{
			effects = {
				{
					kind = "Drop Shadow",
					properties = { blur = 10, spread = 4, shadowOffset = Vector2.new(10, 10), transparency = 0.5 },
				},
			},
		},
	},
})
