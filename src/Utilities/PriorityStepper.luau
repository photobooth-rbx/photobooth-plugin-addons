local RunService = game:GetService("RunService")

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

		local awaitingThreads = self.awaitingThreads
		self.awaitingThreads = {}

		for thread, _ in awaitingThreads do
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, dt)
			end
		end
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
	local dt: number = coroutine.yield()
	return dt
end

function PriorityStepperClass.Destroy(self: PriorityStepper)
	self.connection:Disconnect()
	table.clear(self.callbackInfos)
end

return {
	render = PriorityStepperStatic.new(RunService.PreRender),
	heartbeat = PriorityStepperStatic.new(RunService.Heartbeat),
}
