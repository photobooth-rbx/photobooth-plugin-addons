local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)
local Trove = require(pluginRoot.Packages.Trove)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

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

	self.trove:Add(PriorityStepper.render:connect(RenderPriorities.ANIMATOR, function()
		-- force our dt to zero b/c we manually step the position elsewhere
		self.animator:StepAnimations(0)
	end))

	return self
end

type Options = {
	timePosition: number,
	onStep: (AnimationTrack) -> (),
	onTrackPositionChanged: (AnimationTrack) -> (),
	onTrackLoaded: (AnimationTrack?) -> (),
	onTrackUnloaded: () -> (),
}

function AnimationManagerClass.loadTrack(self: AnimationManager, options: Options)
	self.trackTrove:Clean()
	self.trackTrove:Add(task.spawn(function()
		if Content.fromUri(self.animation.AnimationId) == Content.none then
			options.onTrackLoaded(nil)
			return
		end

		local track = self.animator:LoadAnimation(self.animation)
		track.Looped = true
		self.trackTrove:Add(track)

		while track.Length == 0 do
			PriorityStepper.render:wait()
		end

		track:Play(0, nil, 0)
		track.TimePosition = options.timePosition

		local prevTimePosition = -1
		self.trackTrove:Add(PriorityStepper.render:connect(RenderPriorities.TRACK, function(dt)
			options.onStep(track)
			if prevTimePosition ~= track.TimePosition then
				prevTimePosition = track.TimePosition
				options.onTrackPositionChanged(track)
			end
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
