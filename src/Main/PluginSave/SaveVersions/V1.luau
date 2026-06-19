-- Persisted plugin state. `presets` holds the user-saved post-processing presets in their
-- serialized form (plain tables carrying Color3/Vector2, which Bufferize round-trips). Default
-- presets are rebuilt at runtime and never stored.
export type Serialized = {
	presets: { any },
}

export type Deserialized = {
	presets: { any },
}

local SaveFormatV1 = {}
SaveFormatV1.version = 1

function SaveFormatV1.default(): Deserialized
	return {
		presets = {},
	}
end

function SaveFormatV1.migrate(_previousSerialized: any)
	error(`[SaveFormatV{SaveFormatV1.version}]: Cannot migrate from V1`)
end

function SaveFormatV1.serialize(deserialized: Deserialized): Serialized
	return {
		presets = deserialized.presets,
	}
end

function SaveFormatV1.deserialize(serialized: Serialized): Deserialized
	return {
		presets = serialized.presets or {},
	}
end

return SaveFormatV1
