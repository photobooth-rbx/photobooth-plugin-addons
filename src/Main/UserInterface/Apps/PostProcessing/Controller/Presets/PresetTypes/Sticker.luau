local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("sticker", {
	name = "Sticker",
	layers = {
		{
			effects = {
				{
					kind = "Stroke",
					name = "Outline",
					properties = {
						thickness = 8,
						softness = 1,
						color = Color3.new(1, 1, 1),
					},
				},
				{
					kind = "Drop Shadow",
					name = "Shadow",
					properties = {
						blur = 8,
						spread = 2,
						shadowOffset = Vector2.new(6, 6),
						transparency = 0.5,
					},
				},
			},
		},
	},
})
