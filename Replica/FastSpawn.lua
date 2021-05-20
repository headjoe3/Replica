--!strict

local BF = Instance.new('BindableFunction')

BF.OnInvoke = function(cb: any): any
	return cb()
end

local function FastSpawn(func: any)
	coroutine.resume(
		coroutine.create(function()
			BF:Invoke(func)
		end)
	)
end

return FastSpawn
