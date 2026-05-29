local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)

local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Photobooth = require(pluginRoot.Packages.PhotoboothBindings)
local Signal = require(pluginRoot.Packages.Signal)
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

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

	self.meshDataCache = {}
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

function AutoCaptureControllerClass._cameraStep(
	self: AutoCaptureController,
	callback: (dt: number, cameraCF: CFrame) -> ()
)
	local isFirstFrame = true
	local focusedModelState = assert(self.focusedModelState)

	return PriorityStepper.render:connect(RenderPriorities.CAMERA, function(dt)
		local cameraCF = if isFirstFrame then focusedModelState.cameraCF else workspace.CurrentCamera.CFrame
		isFirstFrame = false
		callback(dt, cameraCF)
	end)
end

-- Methods

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
	local focusedModelState = assert(self.focusedModelState)

	self.refreshTrove:Add(self:_cameraStep(function(dt, readCameraCF)
		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = readCameraCF.Rotation

		local state = self.observableState:get()
		local rectCenter = self.paddedRect.Min + (self.paddedRect.Max - self.paddedRect.Min) / 2

		local aspect = self.paddedRect.Width / self.paddedRect.Height
		local scaleY = self.paddedRect.Height / viewportSize.Y
		local scaledFov2 = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * scaleY)
		local sinFov2 = math.sin(scaledFov2 * math.min(1, aspect))

		local _aabbCenter, aabbSize = focusedModelState.instance:GetBoundingBox()
		local radius = aabbSize.Magnitude / 2

		local distance = (radius / sinFov2) * state.DistanceScale
		local cameraCF = rotation * CFrame.new(0, 0, distance)

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
	end))
end

function AutoCaptureControllerClass._hookPointCloud(self: AutoCaptureController)
	local focusedModelState = assert(self.focusedModelState)
	local pointCloud = self:_createPointCloud(focusedModelState.instance)

	self.refreshTrove:Add(function()
		pointCloud:Destroy()
	end)

	self.refreshTrove:Add(self:_cameraStep(function(dt, readCameraCF)
		local camera = workspace.CurrentCamera
		local viewportSize = camera.ViewportSize
		local rotation = readCameraCF.Rotation
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

		local distorted = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = Enum.CameraType.Custom
		camera.CFrame = distorted
		camera.Focus = distorted

		focusedModelState.cameraCF = cameraCF
	end))
end

function AutoCaptureControllerClass._hookFree(self: AutoCaptureController)
	local focusedModelState = assert(self.focusedModelState)
	self:_cameraStep(function(dt, readCameraCF)
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
		focusedModelState.cameraCF = readCameraCF
	end)
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

function AutoCaptureControllerClass._loadAnimationAsync(self: AutoCaptureController, modelState: ModelState)
	local animator = modelState.instance:FindFirstChildWhichIsA("Animator", true)
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = modelState.animation.content.Uri or ""
	animation.Parent = workspace.CurrentCamera
	self.focusTrove:Add(animation)

	local animationReady = Future.new()
	local animationManager = AnimationManager.new(animator, animation)
	self.focusTrove:Add(function()
		animationManager:Destroy()
	end)

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
				if track then
					self.observableState:update()(function(state)
						state.AnimationTrack = track
						return state
					end)
				end

				if not animationReady:isCompleted() then
					animationReady:complete()
				end
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

	animationReady:expect()
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

function AutoCaptureControllerClass.focusAsync(self: AutoCaptureController, modelState: ModelState)
	self:unfocus()

	local focusReady = Future.new()

	local cameraType = workspace.CurrentCamera.CameraType
	modelState.instance.Parent = workspace.CurrentCamera

	if not self.observableState:get().IsCameraAngleSynced then
		workspace.CurrentCamera.CFrame = modelState.cameraCF
	else
		modelState.cameraCF = workspace.CurrentCamera.CFrame
	end

	self.focusTrove:Add(PriorityStepper.heartbeat:connect(RenderPriorities.CAMERA, function()
		local camera = workspace.CurrentCamera
		camera.CFrame = modelState.cameraCF
	end))

	self.focusTrove:Add(function()
		local camera = workspace.CurrentCamera
		camera.CameraType = cameraType
		camera.CFrame = modelState.cameraCF
		modelState.instance.Parent = nil

		if not focusReady:isCompleted() then
			focusReady:complete()
		end
	end)

	self.focusTrove:Add(task.spawn(function()
		self:_loadAnimationAsync(modelState)

		self.focusedModelState = modelState
		self.focusTrove:Add(function()
			self.focusedModelState = nil
		end)

		local fitType = self.observableState:get().FitType
		self:_refreshFitType()
		self.focusTrove:Add(self.observableState:onChanged(function()
			local newFitType = self.observableState:get().FitType
			if fitType ~= newFitType then
				fitType = newFitType
				self:_refreshFitType()
			end
		end))

		focusReady:complete()
	end))

	focusReady:expect()
end

function AutoCaptureControllerClass.unfocus(self: AutoCaptureController)
	self.refreshTrove:Clean()
	self.focusTrove:Clean()
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

		meshDataCache: PointCloud.MeshDataCache,
		forcePointCloudRefresh: Signal.Signal<()>,

		focusTrove: Trove.Trove,
		refreshTrove: Trove.Trove,
	},
	AutoCaptureControllerClass
))

return AutoCaptureControllerStatic
