local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

-- Sepia: the grade desaturates the layer to greyscale (with lifted blacks and softened
-- contrast for an aged feel), then the warm tint - applied after the grade - multiplies
-- that greyscale into a uniform sepia brown.
return PresetRegistry.register("vintage", {
	name = "Vintage",
	layers = {
		{
			name = "Vintage",
			tintColor = Color3.fromRGB(255, 196, 130),
			brightness = 0.08,
			contrast = 0.9,
			saturation = 0,
			hue = 0,
		},
	},
})
