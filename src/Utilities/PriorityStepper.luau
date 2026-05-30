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

		signal: RBXScriptSignal<number>,
		connection: RBXScriptConnection?,
	},
	PriorityStepperClass
))

function PriorityStepperStatic.new(signal: RBXScriptSignal<number>)
	local self = setmetatable({}, PriorityStepperClass) :: PriorityStepper

	self.ticket = 0
	self.callbackInfos = {}

	self.signal = signal
	self.connection = nil

	return self
end

function PriorityStepperClass._refreshConnection(self: PriorityStepper)
	local nCallbacks = #self.callbackInfos
	if nCallbacks > 0 and not self.connection then
		self.connection = self.signal:Connect(function(dt)
			for _, info in self.callbackInfos do
				info.callback(dt)
			end
		end)
	elseif nCallbacks == 0 and self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
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

	self:_refreshConnection()

	return function()
		local index = table.find(self.callbackInfos, info)
		if index then
			table.remove(self.callbackInfos, index)
			self:_refreshConnection()
		end
	end
end

function PriorityStepperClass.wait(self: PriorityStepper)
	return self.signal:Wait()
end

function PriorityStepperClass.Destroy(self: PriorityStepper)
	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end
	table.clear(self.callbackInfos)
end

return {
	render = PriorityStepperStatic.new(RunService.PreRender),
	heartbeat = PriorityStepperStatic.new(RunService.Heartbeat),
}
