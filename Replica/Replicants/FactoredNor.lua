local FactoredOr = require(script.Parent.FactoredOr)
local Util = require(script.Parent.Parent.Util)
local Context = require(script.Parent.Parent.Context)
local Signal = require(script.Parent.Parent.Signal)

-- class FactoredNor extends FactoredOr
local statics, members, super = FactoredOr.extend()

local metatable = {
	__index = members
}

function members:Pairs()
	return pairs(self.wrapped)
end

function members:ResolveState()
	return not super.ResolveState(self)
end

statics.SerialType = "FactoredNorReplicant"

-- OOP boilerplate
function statics.new(...)
	local self = setmetatable({}, metatable)
	statics.constructor(self, ...)
	return self
end

return statics