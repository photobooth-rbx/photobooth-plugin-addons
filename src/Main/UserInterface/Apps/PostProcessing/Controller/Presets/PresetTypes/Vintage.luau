local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("dropShadow", {
	name = "Vintage",
	layers = {
		{
			name = "Vintage",
			tintColor = Color3.fromRGB(255, 240, 220),
			brightness = 0.03,
			contrast = 1.1,
			saturation = 0.6,
			hue = 8,
		},
	},
})
