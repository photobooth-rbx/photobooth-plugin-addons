local UserInputService = game:GetService("UserInputService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)

local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

local AnimationManager = require(script.AnimationManager)
local PointCloud = require(script.PointCloud)

local PITCH_LIMIT = math.rad(89)

local ORBIT_SENSITIVITY = 0.005

local FREE_LOOK_SENSITIVITY = 0.005
local FREE_MOVE_SPEED_MAX = 1000

local FREE_MOVE_KEYS = {
	[Enum.KeyCode.D] = Vector3.xAxis,
	[Enum.KeyCode.A] = -Vector3.xAxis,
	[Enum.KeyCode.E] = Vector3.yAxis,
	[Enum.KeyCode.Q] = -Vector3.yAxis,
	[Enum.KeyCode.S] = Vector3.zAxis,
	[Enum.KeyCode.W] = -Vector3.zAxis,
}

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

	local yaw, pitch = math.pi, 0
	self.sharedCameraState = {
		yaw = yaw,
		pitch = pitch,
		prevCF = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0),
	}

	self.focusedModel = nil
	self.stateByModel = {}

	self.isInputFrozen = true
	self.meshDataCache = {}

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

local function getStudioSetting<T>(key: string, default: T)
	local success, value = pcall(function()
		return (settings().Studio :: any)[key] :: T
	end)
	return if success then value else default
end

-- Methods

function AutoCaptureControllerClass._getActiveCameraState(self: AutoCaptureController)
	local focusedModel = self.focusedModel
	local focusedModelState = focusedModel and self.stateByModel[focusedModel]
	if focusedModelState and not self.observableState:get().IsCameraAngleSynced then
		return focusedModelState.cameraState
	end
	return self.sharedCameraState
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

		local cameraState = self:_getActiveCameraState()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rotating then
				cameraState.yaw -= input.Delta.X * ORBIT_SENSITIVITY
				cameraState.pitch =
					math.clamp(cameraState.pitch - input.Delta.Y * ORBIT_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
			end
		end
	end))

	local cameraTrove = Trove.new()

	local function cameraAdded(camera: Camera)
		cameraTrove:Clean()
		cameraTrove:Add(camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			local cameraState = self:_getActiveCameraState()
			local rx, ry, _rz = camera.CFrame:ToEulerAnglesYXZ()
			cameraState.pitch = rx
			cameraState.yaw = ry
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
		local cameraState = self:_getActiveCameraState()

		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(cameraState.pitch, cameraState.yaw, 0)

		local state = self.observableState:get()
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local aspect = self.paddedRect.Width / self.paddedRect.Height
		local scaleY = self.paddedRect.Height / viewportSize.Y
		local scaledFov2 = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * scaleY)
		local sinFov2 = math.sin(scaledFov2 * math.min(1, aspect))

		local _aabbCenter, aabbSize = focusedModel:GetBoundingBox()
		local radius = aabbSize.Magnitude / 2

		local distance = (radius / sinFov2) * state.DistanceScale
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

		cameraState.prevCF = distortedCF
		focusedModelState.cameraState = table.clone(cameraState)
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
		local cameraState = self:_getActiveCameraState()

		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(cameraState.pitch, cameraState.yaw, 0)
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

		cameraState.prevCF = distortedCF
		focusedModelState.cameraState = table.clone(cameraState)
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

	-- Drive the camera ourselves on top of CameraType.Scriptable rather than
	-- handing control to Studio's edit-mode camera (which snaps on first input).
	-- Hold the right mouse button to look + fly: WASD move, E/Q up/down, Shift to slow speed
	local startCF = focusedModelState.cameraState.prevCF
	local position = startCF.Position
	local pitch, yaw = startCF:ToEulerAnglesYXZ()
	local moveSpeed = 0

	local function isShiftDown()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end

	cleanupTrove:Add(UserInputService.InputChanged:Connect(function(input, gameProcessed)
		if self.isInputFrozen then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * FREE_LOOK_SENSITIVITY
			pitch = math.clamp(pitch - input.Delta.Y * FREE_LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		end
	end))

	local function render(dt: number)
		local cameraState = self:_getActiveCameraState()

		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Scriptable

		local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)

		if not self.isInputFrozen then
			local studioCameraSpeed = getStudioSetting("Camera Speed", 1.5) * 10
			local studioShiftSpeed = getStudioSetting("Shift Speed", 0.2) * 10

			if isShiftDown() then
				moveSpeed = studioShiftSpeed
			else
				local newMoveSpeed = math.max(moveSpeed, studioCameraSpeed) + dt * (studioCameraSpeed / 2)
				moveSpeed = math.clamp(newMoveSpeed, studioShiftSpeed, FREE_MOVE_SPEED_MAX)
			end

			local move = Vector3.zero
			for keyCode, vec in FREE_MOVE_KEYS do
				if UserInputService:IsKeyDown(keyCode) then
					move = move + rotation:VectorToWorldSpace(vec)
				end
			end

			local moveMagnitude = move.Magnitude
			if moveMagnitude > 0 then
				local moveUnit = move / moveMagnitude
				position = position + moveUnit * moveSpeed * dt
			else
				moveSpeed = 0
			end
		end

		local cameraCF = CFrame.new(position) * rotation
		camera.CFrame = cameraCF
		camera.Focus = cameraCF

		cameraState.pitch = pitch
		cameraState.yaw = yaw
		cameraState.prevCF = cameraCF
		focusedModelState.cameraState = table.clone(cameraState)
	end

	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render(0)

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
	local cameraState = table.clone(self.sharedCameraState)
	local animationManager = AnimationManager.new(model)

	globalTicket = globalTicket + 1

	self.stateByModel[model] = {
		ticket = globalTicket,
		cameraState = cameraState,
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
		focusedModelState.cameraState = table.clone(self.sharedCameraState)
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

type CameraState = {
	yaw: number,
	pitch: number,
	prevCF: CFrame,
}

type ModelState = {
	ticket: number,
	cameraState: CameraState,
	animationManager: AnimationManager.AnimationManager,
}

export type State = typeof(AutoCaptureControllerStatic.createState():get())
export type ObservableState = ObservableValue.ObservableValue<State>

export type AutoCaptureController = typeof(setmetatable(
	{} :: {
		captureRect: Rect,
		paddedRect: Rect,
		observableState: ObservableState,

		sharedCameraState: CameraState,

		focusedModel: Model?,
		stateByModel: { [Model]: ModelState },

		isInputFrozen: boolean,
		meshDataCache: PointCloud.MeshDataCache,

		focusTrove: Trove.Trove,
		refreshTrove: Trove.Trove,
	},
	AutoCaptureControllerClass
))

return AutoCaptureControllerStatic
