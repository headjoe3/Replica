local Signal; do
	Signal = {}
	Signal.__index = {
		Connect = function(self, callback)
			local obj = {Connected = true, Disconnect = function() end}
			local wrappedCB = function()
				if obj.Connected then
					callback()
				end
			end
			obj = {
				Connected = true
				Disconnect = function()obj.Connected = false self.cbSet[wrappedCB] = nil end
			}
			self.cbSet[wrappedCB] = true
			return obj
		end,
		Fire = function(self, ...)
			local cbs = {}
			for cb in pairs(self.cbSet) do
				table.insert(cbs, cb)
			end
			
			for i = 1, #cbs do
				coroutine.wrap(cbs[i])(...)
			end
			local threads = self.suspendedThreads
			self.suspendedThreads = {}
			for i = 1, #threads do
				coroutine.resume(threads[i], ...)
			end
		end,
		Wait = function(self)
			table.insert(self.suspendedThreads, coroutine.running())
			return coroutine.yield()
		end,
		Destroy = function(self)
			self.cbSet = {}
			self.suspendedThreads = {}
		end,
	}
	Signal.new = function(...)
		return Signal.constructor(setmetatable({}, Signal), ...)
	end
	Signal.constructor = function(self)
		self.cbSet = {}
		self.suspendedThreads = {}
		return self
	end
end

return Signal
