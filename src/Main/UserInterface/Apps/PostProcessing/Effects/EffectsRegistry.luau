local EffectsRegistry = {}

export type ImageInputs = {
	img: EditableImage,
	svf: EditableImage,
	integral: EditableImage,
	output: EditableImage,
}

export type Effect<Properties> = {
	kind: string,
	name: string,
	index: number,
	playerCreated: boolean,
	renderTicket: number,
	properties: Properties,
}

export type EffectProps<Properties> = {
	Effect: Effect<Properties>,
	UpdateEffect: ((Effect<Properties>) -> Effect<Properties>) -> (),
	Disabled: boolean?,
}

export type Registration<Properties> = {
	playerCreated: boolean,
	-- Composite this effect above the layer's base image instead of behind it.
	renderAboveBase: boolean?,
	create: () -> Properties,
	render: (ImageInputs, Properties) -> (),
}

local effectByIndex = {}
local effectByKind = {}

function EffectsRegistry.register<Properties>(kind: string, registration: Registration<Properties>)
	local effectEntry = {
		kind = kind,
		index = #effectByIndex + 1,
		playerCreated = registration.playerCreated,
		renderAboveBase = registration.renderAboveBase or false,

		create = registration.create,
		render = registration.render,
	}

	table.insert(effectByIndex, effectEntry)
	effectByKind[kind] = effectEntry

	return effectEntry
end

function EffectsRegistry.getByKind(kind: string)
	return effectByKind[kind]
end

local cachedPlayerCreatableKinds: { string }
function EffectsRegistry.getPlayerCreatableKinds()
	if not cachedPlayerCreatableKinds then
		local playerCreatableKinds = {}
		for _, effectEntry in effectByIndex do
			if effectEntry.playerCreated then
				table.insert(playerCreatableKinds, effectEntry.kind)
			end
		end
		table.freeze(playerCreatableKinds)
		cachedPlayerCreatableKinds = playerCreatableKinds
	end
	return cachedPlayerCreatableKinds
end

return EffectsRegistry
