-- Bloxx you, my FastSpawn(tm) is FasterSpawn than your spawn
-- DataBrain, 2019

local FastestSpawn = Instance.new("BindableEvent")
FastestSpawn.Event:Connect(function(callback, argsPointer)
	callback(argsPointer())
end)

local function createPointer(...)
	local args = { ... }
	return function()
		return unpack(args)
	end
end

return function(func, ...)
	assert(type(func) == "function", "Invalid arguments (function expected, got " .. typeof(func) .. ")")
	FastestSpawn:Fire(func, createPointer(...))
end