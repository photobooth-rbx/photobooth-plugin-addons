local pluginRoot = script:FindFirstAncestor("PluginRoot")

local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local Signal = require(pluginRoot.Packages.Signal)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local PriorityStepper = require(appRoot.PriorityStepper)

local AnimationManager = require(script.AnimationManager)
local PointCloud = require(script.PointCloud)

local AutoCaptureControllerStatic = {}

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

	self.forcePointCloudRefresh = Signal.new()

	self.focusTrove = Trove.new()
	self.refreshTrove = Trove.new()

	return self
end

-- Private

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

local function cameraStep(callback: (number) -> CFrame)
	local fallbackCameraCF = workspace.CurrentCamera.CFrame

	local heartbeatCleanup = PriorityStepper.heartbeat:connect(PriorityStepper.STEPS.CAMERA, function()
		workspace.CurrentCamera.CFrame = fallbackCameraCF
	end)

	local renderCleanup = PriorityStepper.render:connect(PriorityStepper.STEPS.CAMERA, function(dt)
		fallbackCameraCF = callback(dt)
	end)

	return function()
		heartbeatCleanup()
		renderCleanup()
	end
end

-- Methods

function AutoCaptureControllerClass._hookOrbital(self: AutoCaptureController)
	local firstSet = true
	local focusedModelState = assert(self.focusedModelState)

	self.refreshTrove:Add(cameraStep(function()
		local camera = workspace.CurrentCamera
		local cameraCF = camera.CFrame

		local state = self.observableState:get()
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local viewportSize = camera.ViewportSize

		local rotation = cameraCF.Rotation
		if firstSet then
			if not self.observableState:get().IsCameraAngleSynced then
				rotation = focusedModelState.cameraCF.Rotation
			end
			firstSet = false
		end

		local aspect = self.paddedRect.Width / self.paddedRect.Height
		local scaleY = self.paddedRect.Height / viewportSize.Y
		local scaledFov2 = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * scaleY)
		local sinFov2 = math.sin(scaledFov2 * math.min(1, aspect))

		local _aabbCenter, aabbSize = focusedModelState.instance:GetBoundingBox()
		local radius = aabbSize.Magnitude / 2

		local distance = (radius / sinFov2) * state.DistanceScale
		cameraCF = rotation * CFrame.new(0, 0, distance)

		local distortedCF = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = distortedCF
		camera.Focus = distortedCF

		focusedModelState.cameraCF = cameraCF

		return cameraCF
	end))
end

function AutoCaptureControllerClass._hookPointCloud(self: AutoCaptureController)
	local firstSet = true

	local focusedModelState = assert(self.focusedModelState)
	local pointCloud = PointCloud.new(focusedModelState.instance, self.observableState:get().TryUseMeshVertices)

	self.refreshTrove:Add(function()
		pointCloud:Destroy()
	end)

	self.refreshTrove:Add(self.observableState:onChanged(function()
		local newTryUseMeshVertices = self.observableState:get().TryUseMeshVertices
		if pointCloud.tryUseMeshVertices ~= newTryUseMeshVertices then
			pointCloud.tryUseMeshVertices = newTryUseMeshVertices
			pointCloud:recalculateVertices()
		end
	end))

	self.refreshTrove:Add(self.forcePointCloudRefresh:Connect(function()
		pointCloud:recalculateVertices()
	end))

	self.refreshTrove:Add(cameraStep(function()
		local camera = workspace.CurrentCamera
		local cameraCF = camera.CFrame

		local state = self.observableState:get()

		local viewportSize = camera.ViewportSize
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local rotation = cameraCF.Rotation
		if firstSet then
			if not self.observableState:get().IsCameraAngleSynced then
				rotation = self.focusedModelState.cameraCF.Rotation
			end
			firstSet = false
		end

		local rotationInv = rotation:Inverse()

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

		cameraCF = rotation * CFrame.new((hMax + hMin) / 2, (vMax + vMin) / 2, furthest + distance)

		local distorted = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = distorted
		camera.Focus = distorted

		self.focusedModelState.cameraCF = cameraCF

		return cameraCF
	end))
end

function AutoCaptureControllerClass._hookFree(self: AutoCaptureController)
	local focusedModelState = assert(self.focusedModelState)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	focusedModelState.cameraCF = CFrame.identity
end

function AutoCaptureControllerClass._refreshFitType(self: AutoCaptureController)
	local state = self.observableState:get()

	self.refreshTrove:Clean()
	if state.FitType == "Orbital" then
		self:_hookOrbital()
	elseif state.FitType == "Point Cloud" then
		self:_hookPointCloud()
	else
		self:_hookFree()
	end
end

function AutoCaptureControllerClass._listenForAnimation(self: AutoCaptureController, modelState: ModelState)
	local animator = modelState.instance:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = modelState.animation.content.Uri or ""
	animation.Parent = workspace.CurrentCamera
	self.focusTrove:Add(animation)

	local animationManager = AnimationManager.new(animator, animation)

	local function refreshTrack()
		animationManager:loadTrack({
			timePosition = modelState.animation.timePosition,
			onStep = function(track)
				modelState.animation.timePosition = track.TimePosition
			end,
			onTrackPositionChanged = function()
				self.forcePointCloudRefresh:Fire()
			end,
			onTrackLoaded = function(track)
				self.observableState:update()(function(state)
					state.AnimationTrack = track
					return state
				end)
			end,
			onTrackUnloaded = function()
				self.observableState:update()(function(state)
					state.AnimationTrack = nil
					return state
				end)
			end,
		})
	end

	refreshTrack()
	self.focusTrove:Add(animation:GetPropertyChangedSignal("AnimationId"):Connect(function()
		animationManager:clearTrack()
		modelState.animation.content = Content.fromUri(animation.AnimationId)
		modelState.animation.timePosition = 0
		refreshTrack()
	end))

	self.focusTrove:Add(function()
		animationManager:Destroy()
	end)
end

function AutoCaptureControllerClass.setCaptureRect(self: AutoCaptureController, rect: Rect)
	self.captureRect = rect
end

function AutoCaptureControllerClass.setPaddedRect(self: AutoCaptureController, rect: Rect)
	self.paddedRect = rect
end

function AutoCaptureControllerClass.getFocusedModelState(self: AutoCaptureController)
	return self.focusedModelState
end

function AutoCaptureControllerClass.focus(self: AutoCaptureController, modelState: ModelState)
	self:unfocus()

	modelState.instance.Parent = workspace.CurrentCamera
	self.focusedModelState = modelState
	local cameraType = workspace.CurrentCamera.CameraType
	self.focusTrove:Add(function()
		modelState.instance.Parent = nil
		self.focusedModelState = nil
		workspace.CurrentCamera.CameraType = cameraType
	end)

	self:_listenForAnimation(modelState)

	local fitType = self.observableState:get().FitType
	self:_refreshFitType()
	self.focusTrove:Add(self.observableState:onChanged(function()
		local newFitType = self.observableState:get().FitType
		if fitType ~= newFitType then
			fitType = newFitType
			self:_refreshFitType()
		end
	end))
end

function AutoCaptureControllerClass.unfocus(self: AutoCaptureController)
	self.focusTrove:Clean()
	self.refreshTrove:Clean()
end

function AutoCaptureControllerClass.capture(self: AutoCaptureController)
	local state = self.observableState:get()
	local result = Photobooth.captureViewport({
		rect = self.captureRect,
		type = state.CaptureType :: any,
		alphaBleed = state.AlphaBleed,
	})

	return result
end

function AutoCaptureControllerClass.Destroy(self: AutoCaptureController)
	self:unfocus()
end

--

export type State = typeof(AutoCaptureControllerStatic.createState():get())
export type ObservableState = ObservableValue.ObservableValue<State>

export type ModelState = {
	instance: Model,
	cameraCF: CFrame,
	animation: {
		content: Content,
		timePosition: number,
	},
}

export type AutoCaptureController = typeof(setmetatable(
	{} :: {
		captureRect: Rect,
		paddedRect: Rect,
		focusedModelState: ModelState?,
		observableState: ObservableState,

		forcePointCloudRefresh: Signal.Signal<()>,

		focusTrove: Trove.Trove,
		refreshTrove: Trove.Trove,
	},
	AutoCaptureControllerClass
))

return AutoCaptureControllerStatic
