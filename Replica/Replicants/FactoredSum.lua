local Replicant = require(script.Parent.Parent.Replicant)
local Signal = require(script.Parent.Parent.Signal)

-- class FactoredSum extends Replicant
local statics, members, super = Replicant.extend()

local metatable = {
	__index = members
}

function members:Pairs()
	return pairs(self.wrapped)
end

function members:_setLocal(key, value, isLocal)
	if type(key) ~= "string" then
		error("FactoredSum Replicant keys must be strings")
	end
	if value ~= nil and type(value) ~= "number" then
		error("FactoredSum Replicant values must be numbers")
	end
	
	self.wrapped[key] = value
end

function members:Reset()
	self:Collate(function()
		for key in pairs(self.wrapped) do
			self:Set(key, false)
		end
	end)
end

function members:ResolveState()
	local sum = 0
	for _, value in pairs(self.wrapped) do
		sum = sum + value
	end
	return sum
end

function members:Destroy()
	super.Destroy(self)
	
	self.StateChanged:Destroy()
	self.StateChanged = nil
end

statics.SerialType = "FactoredSumReplicant"

function statics.constructor(self, initialValues, ...)
	Replicant.constructor(self, ...)
	
	if initialValues ~= nil then
		for k, v in pairs(initialValues) do
			self:_setLocal(k, v)
		end
	end
	
	self.StateChanged = Signal.new()
	self._stateConnections = {}
	
	self.lastState = self:ResolveState()
	self.OnUpdate:Connect(function()
		local newState = self:ResolveState()
		if newState ~= self.lastState then
			self.lastState = newState
			self.StateChanged:Fire(newState)
		end
	end)
end

-- OOP boilerplate
function statics.new(...)
	local self = setmetatable({}, metatable)
	statics.constructor(self, ...)
	return self
end

return statics