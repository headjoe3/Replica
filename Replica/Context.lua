local statics = {}

statics.new = function(base, keyPath, config, active, registryKey)
	local self = {}
	
	self.base = base
	self.keyPath = keyPath
	self.config = config
	self.active = active
	self.registryKey = registryKey
	
	return self
end

return statics