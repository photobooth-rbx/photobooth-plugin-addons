local UserInputService = game:GetService("UserInputService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)

local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local Signal = require(pluginRoot.Packages.Signal)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

local AnimationManager = require(script.AnimationManager)
local PointCloud = require(script.PointCloud)

local ORBIT_SENSITIVITY = 0.005
local ZOOM_SENSITIVITY = 0.08
local PITCH_LIMIT = math.rad(89)
local MIN_ZOOM = 0

local AutoCaptureControllerStatic = {}
local globalTicket = 0

local AutoCaptureControllerClass = {}
AutoCaptureControllerClass.__index = AutoCaptureControllerClass
AutoCaptureControllerClass.ClassName = "AutoCaptureController"

function AutoCaptureControllerStatic.createState()
	return ObservableValue.new({
		AlphaBleed = true,
		CaptureType = "NoSkybox",

		IsFullScreen = false,
		CaptureSize = Vector2.new(256, 256),
		FitType = "Orbital",
		TryUseMeshVertices = false,
		DistanceScale = 1,
		IsCameraAngleSynced = true,

		PaddingVisible = true,
		PaddingUniform = true,
		Padding = 0,
		PaddingTop = 0,
		PaddingRight = 0,
		PaddingBottom = 0,
		PaddingLeft = 0,

		AnimationTrack = nil :: AnimationTrack?,
	})
end

function AutoCaptureControllerStatic.new(observableState: ObservableState)
	local self = setmetatable({}, AutoCaptureControllerClass) :: AutoCaptureController

	self.captureRect = Rect.new(0, 0, 0, 0)
	self.paddedRect = Rect.new(0, 0, 0, 0)
	self.observableState = observableState

	self.sharedOrbit = { yaw = math.pi, pitch = 0, zoom = 1 }
	self.isInputFrozen = true

	self.focusedModel = nil
	self.stateByModel = {}

	self.meshDataCache = {}
	self.forcePointCloudRefresh = Signal.new()

	self.focusTrove = Trove.new()

	return self
end

-- Private

type Distortion = {
	anchor: Vector2,
	position: Vector2,
	size: Vector2,
}

local function distort(camera: Camera, distortion: Distortion)
	local viewportSize = camera.ViewportSize
	local aspectRatio = viewportSize.X / viewportSize.Y

	local hFactor = math.tan(math.rad(camera.FieldOfView) / 2)
	local wFactor = hFactor * aspectRatio

	local center = distortion.position - distortion.size * distortion.anchor + distortion.size / 2

	local w, h = distortion.size.X, distortion.size.Y
	local dx = 2 * wFactor * (0.5 - center.X)
	local dy = -2 * hFactor * (0.5 - center.Y)
	local dz = 1

	local m = math.max(math.abs(w), math.abs(h), math.abs(dx), math.abs(dy), math.abs(dz))

	return CFrame.new(0, 0, 0, w / m, 0, 0, 0, h / m, 0, dx / m, dy / m, dz / m)
end

local function viewProjectionEdgeHits(cloud: { Vector3 }, axis: "X" | "Y", depth: number, tanFov2: number)
	local max, min = -math.huge, math.huge

	for _, lp in cloud do
		local distance = depth - lp.Z
		local halfSpan = tanFov2 * distance

		local component = (lp :: any)[axis] :: number
		local a = component + halfSpan
		local b = component - halfSpan

		max = math.max(max, a, b)
		min = math.min(min, a, b)
	end

	return max, min
end

-- Methods

function AutoCaptureControllerClass._getActiveOrbit(self: AutoCaptureController)
	local focusedModel = self.focusedModel
	local focusedModelState = focusedModel and self.stateByModel[focusedModel]
	if focusedModelState and not self.observableState:get().IsCameraAngleSynced then
		return focusedModelState.orbit
	end
	return self.sharedOrbit
end

function AutoCaptureControllerClass._listenOrbitInput(self: AutoCaptureController)
	local rotating = false
	local cleanupTrove = Trove.new()

	cleanupTrove:Add(UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not gameProcessed and input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
		end
	end))

	cleanupTrove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
		end
	end))

	cleanupTrove:Add(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if self.isInputFrozen then
			return
		end

		local orbit = self:_getActiveOrbit()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rotating then
				orbit.yaw -= input.Delta.X * ORBIT_SENSITIVITY
				orbit.pitch = math.clamp(orbit.pitch - input.Delta.Y * ORBIT_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
			end
		elseif not gameProcessed and input.UserInputType == Enum.UserInputType.MouseWheel then
			orbit.zoom = math.max(MIN_ZOOM, orbit.zoom - input.Position.Z * ZOOM_SENSITIVITY)
		end
	end))

	local cameraTrove = Trove.new()

	local function cameraAdded(camera: Camera)
		cameraTrove:Clean()
		cameraTrove:Add(camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			local orbit = self:_getActiveOrbit()
			local rx, ry, _rz = camera.CFrame:ToEulerAnglesYXZ()
			orbit.pitch = rx
			orbit.yaw = ry
		end))
	end

	cameraAdded(workspace.CurrentCamera)
	local currentCameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		cameraAdded(workspace.CurrentCamera)
	end)

	return function()
		currentCameraChanged:Disconnect()
		cameraTrove:Destroy()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._createPointCloud(self: AutoCaptureController, model: Model)
	local tryUseMeshVertices = self.observableState:get().TryUseMeshVertices
	local pointCloud = PointCloud.new(model, tryUseMeshVertices, self.meshDataCache)

	pointCloud.trove:Add(self.forcePointCloudRefresh:Connect(function()
		pointCloud:recalculateVertices()
	end))

	pointCloud.trove:Add(self.observableState:onChanged(function()
		local newTryUseMeshVertices = self.observableState:get().TryUseMeshVertices
		if pointCloud.tryUseMeshVertices ~= newTryUseMeshVertices then
			pointCloud.tryUseMeshVertices = newTryUseMeshVertices
			pointCloud:recalculateVertices()
		end
	end))

	return pointCloud
end

function AutoCaptureControllerClass._hookOrbital(self: AutoCaptureController)
	local focusedModel = assert(self.focusedModel)
	local focusedModelState = assert(self.stateByModel[focusedModel])

	local cleanupTrove = Trove.new()

	local function render()
		local orbit = self:_getActiveOrbit()

		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0)

		local state = self.observableState:get()
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local aspect = self.paddedRect.Width / self.paddedRect.Height
		local scaleY = self.paddedRect.Height / viewportSize.Y
		local scaledFov2 = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * scaleY)
		local sinFov2 = math.sin(scaledFov2 * math.min(1, aspect))

		local _aabbCenter, aabbSize = focusedModel:GetBoundingBox()
		local radius = aabbSize.Magnitude / 2

		local distance = (radius / sinFov2) * state.DistanceScale * orbit.zoom
		local cameraCF = rotation * CFrame.new(0, 0, distance)

		local distortedCF = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = distortedCF
		camera.Focus = distortedCF

		focusedModelState.orbit = table.clone(orbit)
		focusedModelState.renderCF = distortedCF
	end

	cleanupTrove:Add(self:_listenOrbitInput())
	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render()

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._hookPointCloud(self: AutoCaptureController)
	local focusedModel = assert(self.focusedModel)
	local focusedModelState = assert(self.stateByModel[focusedModel])

	local cleanupTrove = Trove.new()
	local pointCloud = self:_createPointCloud(focusedModel)

	cleanupTrove:Add(function()
		pointCloud:Destroy()
	end)

	cleanupTrove:Add(focusedModelState.animationManager:onTransform(function()
		pointCloud:recalculateVertices()
	end))

	local function render()
		local orbit = self:_getActiveOrbit()

		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0)
		local rotationInv = rotation:Inverse()

		local state = self.observableState:get()
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local tanYFov2 = math.tan(math.rad(camera.FieldOfView / 2))
		local tanYFov2Scaled = tanYFov2 * (self.paddedRect.Height / viewportSize.Y)
		local tanXFov2Scaled = tanYFov2 * (viewportSize.X / viewportSize.Y) * (self.paddedRect.Width / viewportSize.X)

		local worldPointCloud = pointCloud:getVertices()
		local cloud = { rotationInv * worldPointCloud[1] }
		local furthest = cloud[1].Z
		for i = 2, #worldPointCloud do
			local lp = rotationInv * worldPointCloud[i]
			furthest = math.min(furthest, lp.Z)
			cloud[i] = lp
		end

		local hMax, hMin = viewProjectionEdgeHits(cloud, "X", furthest, tanXFov2Scaled)
		local vMax, vMin = viewProjectionEdgeHits(cloud, "Y", furthest, tanYFov2Scaled)
		local distance = math.max(((hMax - hMin) / 2) / tanXFov2Scaled, ((vMax - vMin) / 2) / tanYFov2Scaled)
			* state.DistanceScale
			* orbit.zoom

		local cameraCF = rotation * CFrame.new((hMax + hMin) / 2, (vMax + vMin) / 2, furthest + distance)

		local distortedCF = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = distortedCF
		camera.Focus = distortedCF

		focusedModelState.orbit = table.clone(orbit)
		focusedModelState.renderCF = distortedCF
	end

	cleanupTrove:Add(self:_listenOrbitInput())
	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render()

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._hookFree(self: AutoCaptureController)
	local focusedModel = assert(self.focusedModel)
	local focusedModelState = assert(self.stateByModel[focusedModel])

	local cleanupTrove = Trove.new()
	cleanupTrove:Add(task.spawn(function()
		local camera = workspace.CurrentCamera
		if self.isInputFrozen then
			camera.CameraType = Enum.CameraType.Scriptable
		else
			camera.CameraType = Enum.CameraType.Fixed
		end

		camera.CFrame = focusedModelState.renderCF
		camera.Focus = camera.CFrame

		cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, function()
			local currentCamera = workspace.CurrentCamera
			currentCamera.CameraType = if self.isInputFrozen then Enum.CameraType.Scriptable else Enum.CameraType.Fixed
			focusedModelState.renderCF = currentCamera.CFrame
		end))
	end))

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._watchFitType(self: AutoCaptureController)
	local fitTypeTrove = Trove.new()

	local function setFitType(fitType: string)
		fitTypeTrove:Clean()
		if fitType == "Orbital" then
			fitTypeTrove:Add(self:_hookOrbital())
		elseif fitType == "Point Cloud" then
			fitTypeTrove:Add(self:_hookPointCloud())
		else
			fitTypeTrove:Add(self:_hookFree())
		end
	end

	local fitType = self.observableState:get().FitType
	setFitType(fitType)

	self.focusTrove:Add(self.observableState:onChanged(function()
		local newState = self.observableState:get()
		if fitType ~= newState.FitType then
			fitType = newState.FitType
			setFitType(fitType)
		end
	end))

	return function()
		fitTypeTrove:Destroy()
	end
end

function AutoCaptureControllerClass.setCaptureRect(self: AutoCaptureController, rect: Rect)
	self.captureRect = rect
end

function AutoCaptureControllerClass.setPaddedRect(self: AutoCaptureController, rect: Rect)
	self.paddedRect = rect
end

function AutoCaptureControllerClass.getFocusedModel(self: AutoCaptureController)
	return self.focusedModel
end

function AutoCaptureControllerClass.loadModel(self: AutoCaptureController, model: Model)
	local orbit = table.clone(self.sharedOrbit)
	local renderCF = CFrame.fromEulerAnglesYXZ(orbit.pitch, orbit.yaw, 0) * CFrame.new(0, 0, orbit.zoom)
	local animationManager = AnimationManager.new(model)

	globalTicket = globalTicket + 1

	self.stateByModel[model] = {
		ticket = globalTicket,
		orbit = orbit,
		renderCF = renderCF,
		animationManager = animationManager,
	}
end

function AutoCaptureControllerClass.unloadModel(self: AutoCaptureController, model: Model)
	local focusedModelState = assert(self.stateByModel[model], "No state exists for the provided model.")
	focusedModelState.animationManager:Destroy()
	self.stateByModel[model] = nil
end

function AutoCaptureControllerClass.focus(self: AutoCaptureController, inputFrozen: boolean, model: Model)
	self:unfocus()

	local focusedModelState = assert(self.stateByModel[model], "No state exists for the provided model.")

	self.focusedModel = model
	self.isInputFrozen = inputFrozen

	local camera = workspace.CurrentCamera
	local prevCameraType = camera.CameraType
	model.Parent = camera

	self.focusTrove:Add(function()
		workspace.CurrentCamera.CameraType = prevCameraType
		model.Parent = nil
	end)

	self.focusTrove:Add(focusedModelState.animationManager:hookTrack(function(track)
		self.observableState:update()(function(state)
			state.AnimationTrack = track
			return state
		end)
	end))

	if self.observableState:get().IsCameraAngleSynced then
		focusedModelState.orbit = table.clone(self.sharedOrbit)
	end

	local stopWatching = self:_watchFitType()
	self.focusTrove:Add(stopWatching)
end

function AutoCaptureControllerClass.unfocus(self: AutoCaptureController)
	self.focusTrove:Clean()
end

function AutoCaptureControllerClass.getModels(self: AutoCaptureController)
	local modelAndIndexArr = {}
	for model, modelState in self.stateByModel do
		table.insert(modelAndIndexArr, {
			index = modelState.ticket,
			model = model,
		})
	end

	table.sort(modelAndIndexArr, function(a, b)
		return a.index < b.index
	end)

	local models = {}
	for _, modelAndIndex in modelAndIndexArr do
		table.insert(models, modelAndIndex.model)
	end

	return models
end

function AutoCaptureControllerClass.capture(self: AutoCaptureController)
	local observedState = self.observableState:get()
	local result = Photobooth.captureViewport({
		rect = self.captureRect,
		type = observedState.CaptureType :: any,
		alphaBleed = observedState.AlphaBleed,
	})

	return result
end

function AutoCaptureControllerClass.Destroy(self: AutoCaptureController)
	self:unfocus()
end

--

type Orbit = {
	yaw: number,
	pitch: number,
	zoom: number,
}

type ModelState = {
	ticket: number,
	orbit: Orbit,
	renderCF: CFrame,
	animationManager: AnimationManager.AnimationManager,
}

export type State = typeof(AutoCaptureControllerStatic.createState():get())
export type ObservableState = ObservableValue.ObservableValue<State>

export type AutoCaptureController = typeof(setmetatable(
	{} :: {
		captureRect: Rect,
		paddedRect: Rect,
		observableState: ObservableState,

		sharedOrbit: Orbit,
		isInputFrozen: boolean,

		focusedModel: Model?,
		stateByModel: { [Model]: ModelState },

		meshDataCache: PointCloud.MeshDataCache,
		forcePointCloudRefresh: Signal.Signal<()>,

		focusTrove: Trove.Trove,
		refreshTrove: Trove.Trove,
	},
	AutoCaptureControllerClass
))

return AutoCaptureControllerStatic
