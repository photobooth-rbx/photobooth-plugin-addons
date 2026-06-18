local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("dropShadow", {
	name = "Black & White",
	layers = {
		{ contrast = 1.15, saturation = 0 },
	},
})
