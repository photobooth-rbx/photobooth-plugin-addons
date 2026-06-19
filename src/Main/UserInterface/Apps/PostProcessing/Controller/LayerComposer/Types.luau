export type Layer = {
	name: string,
	editImage: EditableImage,
	offset: Vector2,
	tintColor: Color3,
	transparency: number,
}

-- A colour grade applied to the composited result (not per-layer). Identity is
-- brightness 0, contrast 0, saturation 0, hue 0.
export type Adjustment = {
	brightness: number,
	contrast: number,
	saturation: number,
	hue: number,
}

return {}
