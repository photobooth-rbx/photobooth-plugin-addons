local RunService = game:GetService("RunService")
local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local AnimationManagerStatic = {}

local AnimationManagerClass = {}
AnimationManagerClass.__index = AnimationManagerClass
AnimationManagerClass.ClassName = "AnimationManager"

export type AnimationManager = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,
		trackTrove: Trove.Trove,

		animator: Animator,
		animation: Animation,
	},
	AnimationManagerClass
))

function AnimationManagerStatic.new(animator: Animator, animation: Animation)
	local self = setmetatable({}, AnimationManagerClass) :: AnimationManager

	self.trove = Trove.new()
	self.trackTrove = Trove.new()

	self.animator = animator
	self.animation = animation

	self.trove:Add(RunService.PreRender:Connect(function(dt)
		self.animator:StepAnimations(dt)
	end))

	return self
end

type Options = {
	timePosition: number,
	onStep: (AnimationTrack) -> (),
	onTrackLoaded: (AnimationTrack) -> (),
	onTrackUnloaded: () -> (),
}

function AnimationManagerClass.loadTrack(self: AnimationManager, options: Options)
	self.trackTrove:Clean()
	self.trackTrove:Add(task.spawn(function()
		if Content.fromUri(self.animation.AnimationId) == Content.none then
			return
		end

		local track = self.animator:LoadAnimation(self.animation)
		self.trackTrove:Add(track)

		while track.Length == 0 do
			RunService.PreRender:Wait()
		end

		track:Play(0, nil, 0)
		track.TimePosition = options.timePosition

		self.trackTrove:Add(RunService.PreRender:Connect(function()
			options.onStep(track)
		end))

		self.trackTrove:Add(function()
			track:Stop(0)
			track:Destroy()
			options.onTrackUnloaded()
		end)

		options.onTrackLoaded(track)
	end))
end

function AnimationManagerClass.clearTrack(self: AnimationManager)
	self.trackTrove:Clean()
end

function AnimationManagerClass.Destroy(self: AnimationManager)
	self.trackTrove:Destroy()
	self.trove:Destroy()

	self.animator:StepAnimations(0)
end

return AnimationManagerStatic
