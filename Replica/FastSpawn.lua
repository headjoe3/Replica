--!strict

local BF = Instance.new('BindableFunction')

BF.OnInvoke = function(cb: any): any
	return cb()
end

local function FastSpawn(func: any ...)
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
