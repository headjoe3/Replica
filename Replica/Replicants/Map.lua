local Replicant = require(script.Parent.Parent.Replicant)

-- class Map extends Replicant
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

function members:Pairs()
	return pairs(self.wrapped)
end

function members:_setLocal(key, value, isLocal)
	if type(key) ~= "string" then
		error("Map Replicant keys must be strings")
	end
	
	self.wrapped[key] = value
end

statics.SerialType = "MapReplicant"

function statics.constructor(self, initialValues, ...)
	Replicant.constructor(self, ...)
	
	if initialValues ~= nil then
		for k, v in pairs(initialValues) do
			self:_setLocal(k, v)
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