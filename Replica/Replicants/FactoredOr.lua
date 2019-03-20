local Replicant = require(script.Parent.Parent.Replicant)
local Signal = require(script.Parent.Parent.Signal)

-- class FactoredOr extends Replicant
local statics, members, super = Replicant.extend()

local metatable = {
	__index = members
}

function members:Pairs()
	return pairs(self.wrapped)
end

function members:_setLocal(key, value, isLocal)
	if type(key) ~= "string" then
		error("FactoredOr Replicant keys must be strings")
	end
	
	self.wrapped[key] = value
end

function members:Set(key, value)
	if type(value) ~= "boolean" then
		error("FactoredOr Replicant values must be boolean")
	end
	if value == true then
		super.Set(self, key, true)
	else
		super.Set(self, key, nil)
	end
end

function members:Reset()
	self:Collate(function()
		for key in pairs(self.wrapped) do
			self:Set(key, false)
		end
	end)
end

function members:Toggle(key)
	if self.wrapped[key] then
		self:Set(key, false)
	else
		self:Set(key, true)
	end
end

function members:ResolveState()
	if next(self.wrapped) ~= nil then
		return true
	else
		return false
	end
end

function members:Destroy()
	super.Destroy(self)
	
	self.StateChanged:Destroy()
	self.StateChanged = nil
end

statics.SerialType = "FactoredOrReplicant"

function statics.constructor(self, initialValues, ...)
	Replicant.constructor(self, ...)
	
	if initialValues ~= nil then
		for k, v in pairs(initialValues) do
			if type(v) ~= "boolean" then
				error("FactoredOr Replicant values must be boolean")
			end
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

-- OOP boilerplate
function statics.extend()
	local subclassStatics, subclassMembers = setmetatable({}, {__index = statics}), setmetatable({}, {__index = members})
	subclassMembers._class = subclassStatics
	return subclassStatics, subclassMembers, members
end

return statics