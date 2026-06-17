local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Effects = require(postProcessingRoot.Effects)

local LayerComposer = require(script.LayerComposer)
local SignedVectorField = require(script.SignedVectorField)
local IntegralImage = require(script.IntegralImage)

-- Types

-- A composited render output, one per visible layer base image and per visible
-- sub-effect, consumed by the ImageViewer and LayerComposer.
export type RenderLayer = LayerComposer.Layer

export type Effect<Properties> = {
	kind: string,
	name: string,
	index: number,
	playerCreated: boolean,
	renderTicket: number,
	properties: Properties,
}

export type LayerEffect = {
	id: string,
	isVisible: boolean,
	effect: Effect<any>,
}

-- The editable model: a layer is an image source (carrying its own offset/tint/
-- transparency) that owns an ordered list of sub-effects.
export type Layer = {
	id: string,
	name: string,
	isVisible: boolean,
	isExpanded: boolean,
	showBaseImage: boolean,
	offset: Vector2,
	tintColor: Color3,
	transparency: number,
	effects: { LayerEffect },
}

-- A saved snapshot of a whole layer stack.
export type Preset = {
	id: string,
	name: string,
	layers: { Layer },
}

-- Helpers

local idCounter = 0
local function nextId(): string
	idCounter += 1
	return tostring(idCounter)
end

local function indexOf<T>(list: { T }, predicate: (T) -> boolean): number?
	for i, value in list do
		if predicate(value) then
			return i
		end
	end
	return nil
end

local function cloneLayer(layer: Layer): Layer
	local clone = table.clone(layer)
	clone.effects = table.clone(layer.effects)
	return clone
end

local function makeLayer(name: string): Layer
	return {
		id = nextId(),
		name = name,
		isVisible = true,
		isExpanded = true,
		showBaseImage = true,
		offset = Vector2.zero,
		tintColor = Color3.new(1, 1, 1),
		transparency = 0,
		effects = {},
	}
end

local function makeLayerEffect(kind: string, name: string): LayerEffect
	local entry = assert(Effects.getByKind(kind))
	return {
		id = nextId(),
		isVisible = true,
		effect = {
			kind = kind,
			name = name,
			index = 0,
			playerCreated = entry.playerCreated,
			renderTicket = 0,
			properties = entry.create(),
		},
	}
end

-- Deep copies a layer stack with fresh ids, so snapshots and applied presets are
-- fully independent of (and from) the live model.
local function copyLayerEffect(item: LayerEffect): LayerEffect
	local effect = table.clone(item.effect)
	effect.properties = table.clone(item.effect.properties)
	return {
		id = nextId(),
		isVisible = item.isVisible,
		effect = effect,
	}
end

local function copyLayers(layers: { Layer }): { Layer }
	local out: { Layer } = {}
	for _, layer in layers do
		local clone = table.clone(layer)
		clone.id = nextId()
		clone.effects = {}
		for _, item in layer.effects do
			table.insert(clone.effects, copyLayerEffect(item))
		end
		table.insert(out, clone)
	end
	return out
end

-- Returns a new layers array with `fn` applied to the layer matching `layerId`.
local function mapLayer(layers: { Layer }, layerId: string, fn: (Layer) -> Layer): { Layer }
	local out = table.clone(layers)
	for i, layer in out do
		if layer.id == layerId then
			out[i] = fn(layer)
			break
		end
	end
	return out
end

-- Returns a new layers array with `fn` applied to the effect matching the ids.
local function mapEffect(
	layers: { Layer },
	layerId: string,
	effectId: string,
	fn: (LayerEffect) -> LayerEffect
): { Layer }
	return mapLayer(layers, layerId, function(layer)
		local clone = cloneLayer(layer)
		local i = indexOf(clone.effects, function(item)
			return item.id == effectId
		end)
		if i then
			clone.effects[i] = fn(clone.effects[i])
		end
		return clone
	end)
end

-- Class

local PostProcessingControllerStatic = {}

local PostProcessingControllerClass = {}
PostProcessingControllerClass.__index = PostProcessingControllerClass
PostProcessingControllerClass.ClassName = "PostProcessingController"

export type PostProcessingController = typeof(setmetatable(
	{} :: {
		editImage: EditableImage?,
		imageTrove: Trove.Trove,

		observableThumbnails: ObservableValue.ObservableValue<{ [string]: EditableImage }>,
		observableLayers: ObservableValue.ObservableValue<{ Layer }>,
		observableComposited: ObservableValue.ObservableValue<{ RenderLayer }>,
		observablePresets: ObservableValue.ObservableValue<{ Preset }>,
	},
	PostProcessingControllerClass
))

function PostProcessingControllerStatic.new()
	local self = setmetatable({}, PostProcessingControllerClass) :: PostProcessingController

	self.editImage = nil
	self.imageTrove = Trove.new()

	self.observableThumbnails = ObservableValue.new({} :: { [string]: EditableImage })
	self.observableLayers = ObservableValue.new({ makeLayer("Image") })
	self.observableComposited = ObservableValue.new({})
	self.observablePresets = ObservableValue.new({} :: { Preset })

	return self
end

function PostProcessingControllerStatic.loadingLayer(editImage: EditableImage)
	local layer: RenderLayer = {
		name = "Image",
		editImage = editImage,
		offset = Vector2.zero,
		tintColor = Color3.new(1, 1, 1),
		transparency = 0,
	}

	return layer
end

-- Editable model

function PostProcessingControllerClass.useLayers(self: PostProcessingController)
	return self.observableLayers:use()
end

function PostProcessingControllerClass.addLayer(self: PostProcessingController, name: string?): string
	local layer = makeLayer(name or "Layer")
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		table.insert(out, layer)
		return out
	end)
	return layer.id
end

function PostProcessingControllerClass.addEffect(
	self: PostProcessingController,
	layerId: string,
	kind: string,
	name: string
): string
	local item = makeLayerEffect(kind, name)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isExpanded = true
			table.insert(clone.effects, item)
			return clone
		end)
	end)
	return item.id
end

function PostProcessingControllerClass.removeLayer(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		local i = indexOf(out, function(layer)
			return layer.id == layerId
		end)
		if i then
			table.remove(out, i)
		end
		return out
	end)
end

function PostProcessingControllerClass.removeEffect(self: PostProcessingController, layerId: string, effectId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			local i = indexOf(clone.effects, function(item)
				return item.id == effectId
			end)
			if i then
				table.remove(clone.effects, i)
			end
			return clone
		end)
	end)
end

function PostProcessingControllerClass.moveLayer(self: PostProcessingController, layerId: string, step: number)
	self.observableLayers:update()(function(layers)
		local out = table.clone(layers)
		local i = indexOf(out, function(layer)
			return layer.id == layerId
		end)
		local j = if i then i + step else nil
		if i and j and out[j] then
			out[i], out[j] = out[j], out[i]
		end
		return out
	end)
end

function PostProcessingControllerClass.moveEffect(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	step: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			local i = indexOf(clone.effects, function(item)
				return item.id == effectId
			end)
			local j = if i then i + step else nil
			if i and j and clone.effects[j] then
				clone.effects[i], clone.effects[j] = clone.effects[j], clone.effects[i]
			end
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerName(self: PostProcessingController, layerId: string, name: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.name = name
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerOffset(self: PostProcessingController, layerId: string, offset: Vector2)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.offset = offset
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerTint(self: PostProcessingController, layerId: string, tintColor: Color3)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.tintColor = tintColor
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerTransparency(
	self: PostProcessingController,
	layerId: string,
	transparency: number
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.transparency = transparency
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setLayerShowBaseImage(
	self: PostProcessingController,
	layerId: string,
	show: boolean
)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.showBaseImage = show
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleLayerVisibility(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isVisible = not clone.isVisible
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleLayerExpanded(self: PostProcessingController, layerId: string)
	self.observableLayers:update()(function(layers)
		return mapLayer(layers, layerId, function(layer)
			local clone = cloneLayer(layer)
			clone.isExpanded = not clone.isExpanded
			return clone
		end)
	end)
end

function PostProcessingControllerClass.toggleEffectVisibility(
	self: PostProcessingController,
	layerId: string,
	effectId: string
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			clone.isVisible = not clone.isVisible
			return clone
		end)
	end)
end

function PostProcessingControllerClass.setEffectName(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	name: string
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			local effect = table.clone(item.effect)
			effect.name = name
			clone.effect = effect
			return clone
		end)
	end)
end

-- Applies a Controller-style effect transform (the same contract the registered
-- effect editor Components use) to a single sub-effect.
function PostProcessingControllerClass.updateEffect(
	self: PostProcessingController,
	layerId: string,
	effectId: string,
	transform: (any) -> any
)
	self.observableLayers:update()(function(layers)
		return mapEffect(layers, layerId, effectId, function(item)
			local clone = table.clone(item)
			local effect = table.clone(item.effect)
			effect.properties = table.clone(item.effect.properties)
			clone.effect = transform(effect)
			return clone
		end)
	end)
end

-- Presets

function PostProcessingControllerClass.usePresets(self: PostProcessingController)
	return self.observablePresets:use()
end

-- Snapshots the current layer stack into a new preset.
function PostProcessingControllerClass.addPreset(self: PostProcessingController, name: string?): string
	local preset: Preset = {
		id = nextId(),
		name = name or `Preset {#self.observablePresets:get() + 1}`,
		layers = copyLayers(self.observableLayers:get()),
	}
	self.observablePresets:update()(function(presets)
		local out = table.clone(presets)
		table.insert(out, preset)
		return out
	end)
	return preset.id
end

function PostProcessingControllerClass.removePreset(self: PostProcessingController, presetId: string)
	self.observablePresets:update()(function(presets)
		local out = table.clone(presets)
		local i = indexOf(out, function(preset)
			return preset.id == presetId
		end)
		if i then
			table.remove(out, i)
		end
		return out
	end)
end

-- Replaces the current layer stack with a fresh copy of the preset's snapshot.
function PostProcessingControllerClass.applyPreset(self: PostProcessingController, presetId: string)
	local presets = self.observablePresets:get()
	local i = indexOf(presets, function(preset)
		return preset.id == presetId
	end)
	if i then
		self.observableLayers:set(copyLayers(presets[i].layers))
	end
end

-- Rendering

function PostProcessingControllerClass.loadImageAsync(self: PostProcessingController, editImage: EditableImage)
	if self.editImage == editImage then
		return
	end

	self:unloadImage()
	self.editImage = editImage

	local isImageLoaded = Future.new()

	local alive = true
	self.imageTrove:Add(function()
		alive = false
		self.observableComposited:set({})
		self.observableThumbnails:set({})
		if not isImageLoaded:isCompleted() then
			isImageLoaded:complete()
		end
	end)

	self.imageTrove:Add(task.spawn(function()
		local svfProcess = SignedVectorField.generate(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			svfProcess:cancel()
		end)

		local unpackSvfEdit = svfProcess:expect()
		if not unpackSvfEdit then
			return
		end

		local svfEdit = unpackSvfEdit()
		self.imageTrove:Add(function()
			svfEdit:Destroy()
		end)

		-- The shared summed-area table of the source alpha, built once here (like the
		-- signed vector field) and read by the shadow effects for O(1) box blurs.
		local integralProcess = IntegralImage.generate(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			integralProcess:cancel()
		end)

		local unpackIntegralEdit = integralProcess:expect()
		if not unpackIntegralEdit then
			return
		end

		local integralEdit = unpackIntegralEdit()
		self.imageTrove:Add(function()
			integralEdit:Destroy()
		end)

		-- The shared, unmodified base image; each visible layer references it and the
		-- compose step applies that layer's offset/tint/transparency.
		local baseEdit = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
		self.imageTrove:Add(function()
			baseEdit:Destroy()
		end)

		-- Rendered sub-effect outputs, cached by effect id + renderTicket so only
		-- effects whose properties actually changed are re-rendered.
		type CacheEntry = { editImage: EditableImage, ticket: number }
		local cache: { [string]: CacheEntry } = {}
		self.imageTrove:Add(function()
			for _, entry in cache do
				entry.editImage:Destroy()
			end
			table.clear(cache)
		end)

		-- Per-layer composite thumbnails, cached by a signature of everything that
		-- affects the layer's composited appearance.
		type ThumbnailEntry = { image: EditableImage, signature: string }
		local thumbnailCache: { [string]: ThumbnailEntry } = {}
		self.imageTrove:Add(function()
			for _, entry in thumbnailCache do
				entry.image:Destroy()
			end
			table.clear(thumbnailCache)
		end)

		local function buildOnce()
			local composited: { RenderLayer } = {}
			local thumbnails: { [string]: EditableImage } = {}
			local seenEffects: { [string]: boolean } = {}
			local seenLayers: { [string]: boolean } = {}

			for _, layer in self.observableLayers:get() do
				if not layer.isVisible then
					continue
				end

				-- `layerRenderLayers` is just this layer, composited into its thumbnail; it
				-- omits the layer's global offset so moving the layer doesn't push the
				-- thumbnail off-canvas. The flat `composited` list (main preview) keeps it.
				local layerRenderLayers: { RenderLayer } = {}
				local signatureParts: { string } = { `L:{layer.tintColor}:{layer.transparency}:{layer.showBaseImage}` }

				if layer.showBaseImage then
					table.insert(composited, {
						name = layer.name,
						editImage = baseEdit,
						offset = layer.offset,
						tintColor = layer.tintColor,
						transparency = layer.transparency,
					})
					table.insert(layerRenderLayers, {
						name = layer.name,
						editImage = baseEdit,
						offset = Vector2.zero,
						tintColor = layer.tintColor,
						transparency = layer.transparency,
					})
				end

				for _, item in layer.effects do
					if not item.isVisible then
						continue
					end

					local effect = item.effect
					local cached = cache[item.id]

					local entry: CacheEntry
					if cached and cached.ticket == effect.renderTicket then
						entry = cached
					else
						local output = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
						local effectEntry = Effects.getByKind(effect.kind)
						effectEntry.render(
								{ img = editImage, svf = svfEdit, integral = integralEdit, output = output },
								effect.properties
							)

						if not alive then
							output:Destroy()
							return
						end

						if cached then
							cached.editImage:Destroy()
						end
						entry = { editImage = output, ticket = effect.renderTicket }
						cache[item.id] = entry
					end

					-- Fold the layer's image properties into each sub-effect: offsets add,
					-- tints multiply, and transparencies compose on the alpha channel.
					local layerTint, effectTint = layer.tintColor, effect.properties.color
					local foldedTint =
						Color3.new(layerTint.R * effectTint.R, layerTint.G * effectTint.G, layerTint.B * effectTint.B)
					local foldedTransparency = 1 - (1 - layer.transparency) * (1 - effect.properties.transparency)

					seenEffects[item.id] = true
					table.insert(composited, {
						name = effect.name,
						editImage = entry.editImage,
						offset = layer.offset + effect.properties.offset,
						tintColor = foldedTint,
						transparency = foldedTransparency,
					})
					-- Thumbnail keeps the effect's own offset but not the layer's.
					table.insert(layerRenderLayers, {
						name = effect.name,
						editImage = entry.editImage,
						offset = effect.properties.offset,
						tintColor = foldedTint,
						transparency = foldedTransparency,
					})
					table.insert(
						signatureParts,
						`{item.id}:{effect.renderTicket}:{effect.properties.offset}:{foldedTint}:{foldedTransparency}`
					)
				end

				-- Compose just this layer's render layers into its thumbnail, reusing the
				-- cached image whenever nothing affecting the layer changed.
				seenLayers[layer.id] = true
				if #layerRenderLayers > 0 then
					local signature = table.concat(signatureParts, "|")
					local cachedThumb = thumbnailCache[layer.id]
					if cachedThumb and cachedThumb.signature == signature then
						thumbnails[layer.id] = cachedThumb.image
					else
						local image = LayerComposer.composeAsync(editImage, layerRenderLayers)
						if not alive then
							image:Destroy()
							return
						end
						if cachedThumb then
							cachedThumb.image:Destroy()
						end
						thumbnailCache[layer.id] = { image = image, signature = signature }
						thumbnails[layer.id] = image
					end
				elseif thumbnailCache[layer.id] then
					thumbnailCache[layer.id].image:Destroy()
					thumbnailCache[layer.id] = nil
				end
			end

			if not alive then
				return
			end

			for id, entry in cache do
				if not seenEffects[id] then
					entry.editImage:Destroy()
					cache[id] = nil
				end
			end

			for id, entry in thumbnailCache do
				if not seenLayers[id] then
					entry.image:Destroy()
					thumbnailCache[id] = nil
				end
			end

			-- An image is loaded but nothing is visible (e.g. base image hidden, no
			-- effects): show a blank canvas at the base resolution rather than letting
			-- the viewer fall back to its "no image" state.
			if #composited == 0 then
				table.insert(composited, {
					name = "Image",
					editImage = baseEdit,
					offset = Vector2.zero,
					tintColor = Color3.new(1, 1, 1),
					transparency = 1,
				})
			end

			self.observableComposited:set(composited)
			self.observableThumbnails:set(thumbnails)
			if not isImageLoaded:isCompleted() then
				isImageLoaded:complete()
			end
		end

		-- Coalesce rapid model changes: only one rebuild runs at a time, and any
		-- change arriving mid-rebuild schedules exactly one more pass.
		local running = false
		local dirty = false
		local function rebuild()
			if running then
				dirty = true
				return
			end
			running = true
			task.spawn(function()
				repeat
					dirty = false
					local ok = pcall(buildOnce)
					if not ok then
						break
					end
				until not dirty or not alive
				running = false
			end)
		end

		rebuild()
		self.imageTrove:Add(self.observableLayers:onChanged(rebuild))
	end))

	return isImageLoaded:expect()
end

function PostProcessingControllerClass.unloadImage(self: PostProcessingController)
	self.imageTrove:Clean()
	self.editImage = nil
end

function PostProcessingControllerClass.useThumbnails(self: PostProcessingController)
	return self.observableThumbnails:use()
end

function PostProcessingControllerClass.composeImageAsync(self: PostProcessingController, editImage: EditableImage)
	self:loadImageAsync(editImage)

	local composited = self.observableComposited:get()
	local composedEdit = LayerComposer.composeAsync(editImage, composited)

	self:unloadImage()

	return composedEdit
end

function PostProcessingControllerClass.useComposited(self: PostProcessingController)
	return self.observableComposited:use()
end

function PostProcessingControllerClass.Destroy(self: PostProcessingController)
	self.imageTrove:Destroy()
	self.observableThumbnails:Destroy()
	self.observableLayers:Destroy()
	self.observableComposited:Destroy()
	self.observablePresets:Destroy()
end

--

return PostProcessingControllerStatic
