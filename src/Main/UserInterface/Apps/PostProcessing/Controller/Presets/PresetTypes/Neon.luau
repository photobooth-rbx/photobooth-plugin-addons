local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("dropShadow", {
	name = "Neon",
	layers = {
		{
			effects = {
				{
					kind = "Stroke",
					name = "Core",
					properties = { thickness = 2, softness = 1, color = Color3.new(1, 1, 1) },
				},
				{
					kind = "Outer Glow",
					name = "Glow",
					properties = { size = 22, falloff = 2.5, color = Color3.fromRGB(0, 200, 255) },
				},
			},
		},
	},
})
