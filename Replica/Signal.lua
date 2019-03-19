-- Bindables do most of the work (see https://github.com/roblox-ts/roblox-ts/pull/249#issuecomment-464405155
-- for a good reason why); this abstraction attempts to preserve metatables and other objects that
-- BindableEvents do not preserve.

local function createPointer(...)
	local args = { ... }
	return function()
		return unpack(args)
	end
end

local Signal; do
	Signal = {}
	Signal.__index = {
		Connect = function(self, callback)
			return self.wrappedBindable.Event:Connect(function(pointer)
				callback(pointer())
			end)
		end,
		Fire = function(self, ...)
			self.wrappedBindable:Fire(createPointer(...))
		end,
		Wait = function(self)
			local pointer = self.wrappedBindable.Event:Wait()
			return pointer()
		end,
		Destroy = function(self)
			self.wrappedBindable:Destroy()
			self.wrappedBindable = nil
		end,
	}
	Signal.new = function(...)
		return Signal.constructor(setmetatable({}, Signal), ...)
	end
	Signal.constructor = function(self)
		self.wrappedBindable = Instance.new("BindableEvent")
		return self
	end
end

return Signal