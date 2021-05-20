--!nocheck

local BF = Instance.new('BindableFunction')

BF.OnInvoke = function(cb)
	return cb()
end

local function FastSpawn(func, ...)
	local args = { ... }
	coroutine.resume(
		coroutine.create(function()
			BF:Invoke(function()
				cb(unpack(args))
			end)
		end)
	)
end

return FastSpawn
