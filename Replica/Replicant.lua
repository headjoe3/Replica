-- https://www.youtube.com/watch?v=NoAzpa1x7jU

local DefaultConfig = require(script.Parent.DefaultConfig)
local Util = require(script.Parent.Util)
local FastSpawn = require(script.Parent.FastSpawn)
local Context = require(script.Parent.Context)
local Signal = require(script.Parent.Signal)

local RunService = game:GetService("RunService")
local Replicators = script.Parent.Replicators

-- abstract class Replicant
local statics, members = {}, {}

function members:GetConfig()
	return self.config
end

function members:SetConfig(newConfig)
	self.config = newConfig
	self.configInferred = false
	
	self:_setContext(Context.new(self.context.base, self.context.keyPath, newConfig))
end

function members:_hookListeners()
	local replicator = Replicators:FindFirstChild(self.context.registryKey)
	if replicator == nil then
		error("Replicator not found for key '" .. self.context.registryKey .. "'; you should not receive errors like this")
	end
	
	self._connections = {}
	if RunService:IsServer() then
		table.insert(self._connections, replicator.OnServerEvent:Connect(function(client, buffer)
			-- Fail silently if the client does not have the correct permissions
			if self:VisibleToClient(client) then
				if self.config.ClientCanSet then
					self:_applyUpdate(buffer)
				end
			end
		end))
	else
		table.insert(self._connections, replicator.OnClientEvent:Connect(function(buffer)
			self:_applyUpdate(buffer)
		end))
	end
end

function members:_setContext(context)
	self.context = context
	if not context.active then return end
	
	if self.configInferred then
		self.config = context.config
	elseif self.partialConfig ~= nil then
		self.config = Util.OverrideDefaults(context.config, self.partialConfig)
	end
	
	-- Recursively update config context in wrapped descendants
	for k, v in pairs(self.wrapped) do
		if type(v) == "table" and rawget(v, "_isReplicant") == true then
			local extendedPath = Util.Copy(context.keyPath)
			extendedPath[#extendedPath + 1] = k
			
			v:_setContext(Context.new(context.base, extendedPath, self.config, context.active, context.registryKey))
		end
	end
	
	-- Disconnect contextual replication listeners
	if self._connections ~= nil then
		for _, connection in pairs(self._connections) do
			connection:Disconnect()
		end
		
		self._connections = nil
	end
	
	-- Hook contextual replication listeners
	if context.base == self and context.active then
		self:_hookListeners()
	end
end

function members:_inCollatingContext()
	if self.collating then
		return true
	end
	
	local keyPath = self.context.keyPath
	if #keyPath > 0 then
		local base = self.context.base
		for i = 1, #keyPath - 1 do
			base = base.wrapped[keyPath[i]]
		end
		
		return base:_inCollatingContext()
	end
	
	return false
end

function members:_inLocalContext()
	if self.localContext then
		return true
	end
	
	local keyPath = self.context.keyPath
	if #keyPath > 0 then
		local base = self.context.base
		for i = 1, #keyPath - 1 do
			base = base.wrapped[keyPath[i]]
		end
		
		return base:_inLocalContext()
	end
	
	return false
end

function members:Get(key)
	return self.wrapped[key]
end

function members:Set(key, value)
	local isLocal = self:_inLocalContext()
	
	self.WillUpdate:Fire(isLocal)
	local valueWillUpdateSignal = self.valueWillUpdateSignals[key]
	if valueWillUpdateSignal then
		valueWillUpdateSignal:Fire(isLocal)
	end
	
	self:_setLocal(key, value)
	
	if self.context.active then
		-- Update context for nested replicants
		if type(value) == "table" and rawget(value, "_isReplicant") then
			local extendedPath = Util.Copy(self.context.keyPath)
			extendedPath[#extendedPath + 1] = key
			
			value:_setContext(Context.new(self.context.base, extendedPath, self.config, self.context.active, self.context.registryKey))
		end
		
		-- Add to replication buffer
		if not isLocal then
			self:_bufferRawUpdate(key, value)
			if not self:_inCollatingContext() then
				self:_flushReplicationBuffer()
			end
		end
	end
	
	self.OnUpdate:Fire(isLocal)
	local valueOnUpdateSignal = self.valueOnUpdateSignals[key]
	if valueOnUpdateSignal then
		valueOnUpdateSignal:Fire(isLocal)
	end
end

function members:_setLocal(key)
	error("Abstract method _setLocal() was not implemented; you should not see errors like this")
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
function members:Serialize(atKey)
	local symbolicValue = {}
	
	for k, v in pairs(self.wrapped) do
		if typeof(v) == "table" and rawget(v, "_isReplicant") then
			symbolicValue[#symbolicValue + 1] = v:Serialize(k)
		else
			symbolicValue[#symbolicValue + 1] = Util.Serialize(k, v)
		end
	end
	
	return {atKey, self._class.SerialType, symbolicValue, self._preservationId}
end

function members:Collate(callback)
	if self:_inCollatingContext() then
		error("Replicant:Collate() cannot be called concurrently")
	end
	self.collating = true
	
	FastSpawn(function()
		callback();
		
		self:_flushReplicationBuffer()
		
		self.collating = false
	end)
	
	if self.collating then
		error("Yielding is not allowed when calling Replicant:Collate()")
	end
end

function members:_flushReplicationBuffer()
	local buffer = self.context.base.replicationBuffer
	self.context.base.replicationBuffer = {}
	
	if #buffer == 0 then
		return
	end
	
	if not self.context.active or self.context.registryKey == nil then
		error("Attempt to replicate from an unregistered Replicant; use Replica.Register first!")
	end
	local replicator = Replicators:FindFirstChild(self.context.registryKey)
	if replicator == nil then
		error("Replicator not found for key '" .. self.context.registryKey .. "'; you should not receive errors like this")
	end
	
	statics.RegisterSubclasses()
	
	if RunService:IsServer() then
		if self.config.ServerCanSet then
			for _, client in pairs(game.Players:GetPlayers()) do
				local partialBuffer = {}
				
				for _, serialized in pairs(buffer) do
					local nestedSerialized = serialized
					local nestedReplicant = self.context.base
					repeat
						local topLevel = false
						local key, newSerialType, newPartialSymbolicValue, preservationId = unpack(nestedSerialized)
						if statics._subclasses[newSerialType] ~= nil then
							nestedSerialized = newPartialSymbolicValue[1]
							nestedReplicant = nestedReplicant.wrapped[key]
						else
							topLevel = true
						end
					until topLevel or not nestedReplicant
					
					if nestedReplicant then
						if nestedReplicant:VisibleToClient(client) then
							partialBuffer[#partialBuffer + 1] = serialized
						end
					end
				end
				if #partialBuffer > 0 then
					replicator:FireClient(client, partialBuffer)
				end
			end
		else
			error("Replication is not allowed on the server for this configuration (Consider wrapping call in :Local())")
		end
	else
		if self.config.ClientCanSet then
			replicator:FireServer(buffer)
		else
			error("Replication is not allowed on the client for this configuration (Consider wrapping call in :Local())")
		end
	end
end

function members:_applyUpdate(buffer, destroyList, relocatedList, updateList)
	destroyList = destroyList or {}
	updateList = updateList or {}
	relocatedList = relocatedList or {}
	
	local isLocal = self:_inLocalContext()
	
	self.WillUpdate:Fire(isLocal)
	updateList[self] = true

	local existingByPreservationID = {}
	for _, existing in pairs(self.wrapped) do
		if type(existing) == "table" and rawget(existing, "_isReplicant") and existing._preservationId ~= nil then
			existingByPreservationID[existing._preservationId] = existing
		end
	end
	
	for _, serialized in pairs(buffer) do
		local key, newSerialType, newPartialSymbolicValue, preservationId = unpack(serialized)
		
		local existing = self.wrapped[key]
		if existing == nil then
			self.wrapped[key] = statics.FromSerialized(serialized, self.config, self.context)
		else
			local displacedExisting = preservationId and existingByPreservationID[preservationId]
			if displacedExisting then
				-- Re-add displaced object
				destroyList[displacedExisting] = nil
				relocatedList[displacedExisting] = true

				self.wrapped[key] = displacedExisting
				
				-- Update keypath context for displaced items
				if existing ~= displacedExisting then
					local extendedPath = Util.Copy(self.context.keyPath)
					extendedPath[#extendedPath + 1] = key
					
					displacedExisting:_setContext(Context.new(self.context.base, extendedPath, self.config, self.context.active, self.context.registryKey))
				end
				
				-- Update buffered items
				if #newPartialSymbolicValue > 0 then
					displacedExisting:_applyUpdate(newPartialSymbolicValue, destroyList, relocatedList, updateList)
				end
			else
				if type(existing) == "table" and rawget(existing, "_isReplicant") then
					if not relocatedList[existing] then
						destroyList[existing] = true
					end
				end
			
				local newObject = statics.FromSerialized(serialized, self.config, self.context)
				self.wrapped[key] = newObject
				if type(newObject) == "table" and rawget(existing, "_isReplicant") then
					if newObject._preservationId ~= nil then
						existingByPreservationID[newObject._preservationId] = newObject
					end
				end
			end
		end
	end
	
	-- Destroy/update replicants after all actions in the buffer have been completed
	if self.context.base == self then
		for replicant in pairs(updateList) do
			replicant.OnUpdate:Fire(isLocal)
		end
		
		for replicant in pairs(destroyList) do
			replicant:Destroy()
		end
	end
end

function members:_bufferRawUpdate(wrappedKey, wrappedValue)
	local qualifiedBuffer = self.context.base.replicationBuffer
	
	local keyIndex = 1
	local key = self.context.keyPath[keyIndex]
	local base = self.context.base
	while key ~= nil and base ~= nil do
		local nextBase = base.wrapped[key]
		if nextBase == nil then
			error("Invalid keypath '" .. table.concat(self.context.keyPath, ".") .. "'; you should not receive errors like this")
		end
		
		local nextBuffer = {}
		qualifiedBuffer[#qualifiedBuffer + 1] = {key, nextBase._class.SerialType, nextBuffer, nextBase._preservationId}
		qualifiedBuffer = nextBuffer
		
		keyIndex = keyIndex + 1
		key = self.context.keyPath[keyIndex]
		base = nextBase
	end
	
	if not self.context.active or self.context.registryKey == nil then
		error("Attempt to replicate from an unregistered Replicant; use Replica.Register first!")
	end
	
	if type(wrappedValue) == "table" and rawget(wrappedValue, "_isReplicant") then
		qualifiedBuffer[#qualifiedBuffer + 1] = wrappedValue:Serialize(wrappedKey)
	else
		qualifiedBuffer[#qualifiedBuffer + 1] = Util.Serialize(wrappedKey, wrappedValue)
	end
end

function members:Local(callback)
	if self:_inLocalContext() then
		error("Replicant:Local() cannot be called concurrently")
	end
	self.localContext = true
	
	FastSpawn(function() callback(); self.localContext = false end)
	
	if self.localContext then
		error("Yielding is not allowed when calling Replicant:Local()")
	end
end

function members:GetValueWillUpdateSignal(key)
	local signal = self.valueWillUpdateSignals[key]
	if signal ~= nil then
		return signal
	else
		signal = Signal.new()
		self.valueWillUpdateSignals[key] = signal
		return signal
	end
end

function members:GetValueOnUpdateSignal(key)
	local signal = self.valueOnUpdateSignals[key]
	if signal ~= nil then
		return signal
	else
		signal = Signal.new()
		self.valueOnUpdateSignals[key] = signal
		return signal
	end
end

function members:VisibleToClient(client)
	if self.config.SubscribeAll then
		for _, otherClient in pairs(self.config.Blacklist) do
			if otherClient == client then
				return false
			end
		end
		return true
	else
		for _, otherClient in pairs(self.config.Whitelist) do
			if otherClient == client then
				return true
			end
		end
		return false
	end
end

function members:VisibleToAllClients()
	return self.config.SubscribeAll and #self.config.Blacklist == 0
end

function members:Destroy()
	self:_setContext(Context.new(
		self,
		{},
		self.partialConfig and Util.OverrideDefaults(DefaultConfig, self.partialConfig) or DefaultConfig,
		false,
		nil
	))
	self.WillUpdate:Destroy()
	self.OnUpdate:Destroy()
	
	self.WillUpdate = nil
	self.OnUpdate = nil
	
	if self._connections ~= nil then
		for _, connection in pairs(self._connections) do
			connection:Disconnect()
		end
		
		self._connections = nil
	end
	
	for _, signal in pairs(self.valueWillUpdateSignals) do
		signal:Destroy()
	end
	self.valueWillUpdateSignals = nil
	
	for _, signal in pairs(self.valueOnUpdateSignals) do
		signal:Destroy()
	end
	self.valueOnUpdateSignals = nil
end

-- Serialized values should be in the form {key, type, symbolic_value, [preservation_id]}
function statics.FromSerialized(serialized, partialConfig, context)
	if type(serialized) ~= "table" or type(serialized[2]) ~= "string" then
		error("Bad argument #1 to Replicant.FromSerialized (value is not a serialized table)")
	end
	local _, serialType, symbolicValue, preservationId = unpack(serialized)
	
	if serialType == "Replicant" then
		error("Unimplemented serial type for some replicant class; you should not receive errors like this")
	end
	
	-- Check subclasses
	statics.RegisterSubclasses()
	for subclassSerialType, class in pairs(statics._subclasses) do
		if subclassSerialType == serialType then
			local object = class.new(nil, partialConfig, context)
			object._preservationId = preservationId
			object:_applyUpdate(symbolicValue)
			return object
		end
	end
	
	-- Check primitives/rbx datatypes
	return Util.Deserialize(serialized)
end

function statics.RegisterSubclasses()
	if statics._subclasses == nil then
		statics._subclasses = {}
		for _, child in pairs(script.Parent.Replicants:GetChildren()) do
			if child:IsA("ModuleScript") then
				local subclass = require(child)
				statics._subclasses[subclass.SerialType] = subclass
			end
		end
	end
end

-- Should be implemented
statics.SerialType = "Replicant"

function statics.constructor(self, partialConfig, context)
	local configInferred = partialConfig == nil
	if configInferred then
		self.configInferred = true
		self.config = DefaultConfig
	else
		self.configInferred = false
		self.config = Util.OverrideDefaults(DefaultConfig, partialConfig)
		self.partialConfig = partialConfig
	end
	self.collating = false
	self.localContext = false
	self.wrapped = {}
	self.context = context or Context.new(self, {}, self.config, false, nil)
	self.replicationBuffer = {}
	self._isReplicant = true
	self._connections = nil
	
	self.WillUpdate = Signal.new()
	self.OnUpdate = Signal.new()
	
	self.valueWillUpdateSignals = {}
	self.valueOnUpdateSignals = {}
	
	self._preservationId = Util.NextId()
end

-- OOP boilerplate
function statics.extend()
	local subclassStatics, subclassMembers = setmetatable({}, {__index = statics}), setmetatable({}, {__index = members})
	subclassMembers._class = subclassStatics
	return subclassStatics, subclassMembers, members
end

return statics