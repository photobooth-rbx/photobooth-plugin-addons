local RunService = game:GetService("RunService") :: RunService

local PriorityStepperStatic = {}

local PriorityStepperClass = {}
PriorityStepperClass.__index = PriorityStepperClass
PriorityStepperClass.ClassName = "PriorityStepper"

type CallbackInfo = {
	ticket: number,
	priority: number,
	callback: (number) -> (),
}

export type PriorityStepper = typeof(setmetatable(
	{} :: {
		ticket: number,
		callbackInfos: { CallbackInfo },
		awaitingThreads: { [thread]: boolean },

		connection: RBXScriptConnection,
	},
	PriorityStepperClass
))

function PriorityStepperStatic.new(signal: RBXScriptSignal<number>)
	local self = setmetatable({}, PriorityStepperClass) :: PriorityStepper

	self.ticket = 0
	self.callbackInfos = {}
	self.awaitingThreads = {}

	self.connection = signal:Connect(function(dt)
		for _, info in self.callbackInfos do
			info.callback(dt)
		end

		for thread, _ in self.awaitingThreads do
			task.spawn(thread)
		end
		table.clear(self.awaitingThreads)
	end)

	return self
end

function PriorityStepperClass.connect(self: PriorityStepper, priority: number, callback: (dt: number) -> ())
	self.ticket = self.ticket + 1

	local info: CallbackInfo = {
		ticket = self.ticket,
		priority = -math.abs(priority),
		callback = callback,
	}

	table.insert(self.callbackInfos, info)
	table.sort(self.callbackInfos, function(a, b)
		if a.priority ~= b.priority then
			return a.priority > b.priority
		end
		return a.ticket > b.ticket
	end)

	return function()
		local index = table.find(self.callbackInfos, info)
		if index then
			table.remove(self.callbackInfos, index)
		end
	end
end

function PriorityStepperClass.wait(self: PriorityStepper)
	local myThread = coroutine.running()
	self.awaitingThreads[myThread] = true
	coroutine.yield()
end

function PriorityStepperClass.Destroy(self: PriorityStepper)
	self.connection:Disconnect()
	table.clear(self.callbackInfos)
end

local STEPS = {
	TIME_POS = 1,
	ANIMATOR = 2,
	TRACK = 3,
	CAMERA = 4,
}

return {
	STEPS = STEPS,

	render = PriorityStepperStatic.new(RunService.PreRender),
	heartbeat = PriorityStepperStatic.new(RunService.Heartbeat),
}
