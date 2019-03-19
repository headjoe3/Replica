local Replicant = require(script.Parent.Parent.Replicant)

-- class Array extends Replicant
local statics, members = Replicant.extend()

--[[ Syntaxtic sugar is not yet supported.

local metatable = {
	__index = function(self, k)
		local m = members[k]
		if m then
			return m
		end
		
		return self:Get(k)
	end,
	__newindex = function(self, k, v)
		return self:Set(k, v)
	end,
}

]]
local metatable = {
	__index = members
}

function members:IndexOf(value)
	local wrapped = self.wrapped
	for i = 1, #wrapped do
		if wrapped[i] == value then
			return i
		end
	end
	
	return nil
end

function members:Ipairs()
	return ipairs(self.wrapped)
end

function members:Size()
	return #self.wrapped
end

function members:Insert(...)
	if select("#", ...) == 2 then
		local index, value = ...
		if type(index) ~= "number" then
			error("Bad argument #1 to Insert (number expected, got " .. typeof(index) .. ")")
		end
		local function shiftAndInsert()
			local insertIndex = #self.wrapped + 1
			for i = #self.wrapped, index, -1 do
				self:Set(i + 1, self.wrapped[i])
				insertIndex = i
			end
			
			self:Set(insertIndex, value)
		end
		
		if self:_inCollatingContext() then
			shiftAndInsert()
		else
			self:Collate(shiftAndInsert)
		end
	else
		self:Set(#self.wrapped + 1, ( ... ))
	end
end

function members:Remove(index)
	local function shift()
		for i = index, #self.wrapped do
			self:Set(i, self.wrapped[i + 1])
		end
	end
	
	if self:_inCollatingContext() then
		shift()
	else
		self:Collate(shift)
	end
end

function members:Push(value)
	self:Set(#self.wrapped + 1, value)
end

function members:Pop(value)
	self:Set(#self.wrapped, nil)
end

function members:_setLocal(key, value, isLocal)
	if type(key) ~= "number" or key > #self.wrapped + 1 or math.floor(key) ~= key then
		error("Array Replicant keys must be sequential integers")
	end
	
	self.wrapped[key] = value
end

statics.SerialType = "ArrayReplicant"

function statics.constructor(self, initialValues, ...)
	Replicant.constructor(self, ...)
	
	if initialValues ~= nil then
		local expectedi = 1
		for i, v in pairs(initialValues) do
			if i ~= expectedi then
				error("Array Replicant keys must be sequential integers")
			end
			expectedi = expectedi + 1
			
			
			self:_setLocal(i, v)
		end
	end
end

-- OOP boilerplate
function statics.new(...)
	local self = setmetatable({}, metatable)
	statics.constructor(self, ...)
	return self
end

return statics