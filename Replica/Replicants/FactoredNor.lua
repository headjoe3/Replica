local FactoredOr = require(script.Parent.FactoredOr)

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