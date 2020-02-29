-- Robert Tulley
-- MIT license
-- See Documentation: https://github.com/headjoe3/Replica/blob/master/docs/Replica.md

local COLLECTION_TAG = "ReplicaRegisteredKeyInstance"
local INSTANCE_GUID_MATCHING_BUFFER_TIMEOUT = 30

local staticContainers = {
	game:GetService("Workspace"),
	game:GetService("ReplicatedStorage"),
	game:GetService("ServerStorage"),
}
local isInStaticContainer = false

for i = 1, #staticContainers do
	if script:IsDescendantOf(staticContainers[i]) then
		isInStaticContainer = true
		break
	end
end

if not isInStaticContainer then
	error("Replica package must be a descendant of a replicated static container (e.g. ReplicatedStorage)")
end
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Replicators = script.Replicators

local Replicant = require(script.Replicant)
local Context = require(script.Context)
local Signal = require(script.Signal)
local SafeCoro = require(script.SafeCoro)
local FastSpawn = require(script.FastSpawn)

local INSTANCE_GUID_PREFIX = "_InstanceGuid_"
local NewInstanceGuid = function()
	local str = ""
	for i = 1, 30 do
		if math.random() > 0.5 then
			str = str .. string.char(math.random(65, 90))
		else
			str = str .. string.char(math.random(97, 122))
		end
	end
	return INSTANCE_GUID_PREFIX .. str
end

local function IsInstanceGuid(key)
	return key:sub(1, INSTANCE_GUID_PREFIX:len()) == INSTANCE_GUID_PREFIX
end

local Replica = {}
local registry = {}
local instanceGuidMap = {}
local guidInstanceMap = {}
local instanceGuidTrackers = {}

Replica.Array = require(script.Replicants.Array)
Replica.Map = require(script.Replicants.Map)
Replica.FactoredOr = require(script.Replicants.FactoredOr)
Replica.FactoredNor = require(script.Replicants.FactoredNor)
Replica.FactoredSum = require(script.Replicants.FactoredSum)

function Replica.Register(keyRef, replicant)
	local key
	if type(keyRef) == "string"
		or type(keyRef) == "number" then
		key = keyRef
	elseif typeof(keyRef) == "Instance" then
		key = NewInstanceGuid()
		
		if keyRef:IsDescendantOf(game) then
			guidInstanceMap[key] = keyRef
			instanceGuidMap[keyRef] = key
			CollectionService:AddTag(keyRef, COLLECTION_TAG)
			
			-- Unregister if the instance is destroyed or leaves the game tree
			instanceGuidTrackers[keyRef] = keyRef.AncestryChanged:Connect(function()
				if not keyRef:IsDescendantOf(game) then
					Replica.Unregister(keyRef)
				end
			end)
		else
			error("Cannot register on instances outside of the DataModel")
		end
	else
		error("Invalid key '" .. tostring(keyRef) .. "'; only strings, numbers, or Instances can be used as Replica registry keys")
	end
	
	if type(replicant) ~= "table" or not rawget(replicant, "_isReplicant") then
		error("Bad argument #2 for Replica.Register (Replicant expected, got " .. typeof(replicant) .. ")")
	end
	if replicant.context.active then
		error("Replicant was already registered, or is nested in a registered context")
	end
	if RunService:IsServer() then
		local existing = registry[key]
		if existing ~= nil then
			warn("Replicant replaced at duplicate key '" .. key .. "' because it was never unregistered")
			Replica.Unregister(keyRef)
		end
		
		local replicator = Instance.new("RemoteEvent")
		replicator.Name = key
		replicator.Parent = Replicators
		
		registry[key] = replicant
		replicant:_setContext(Context.new(
			replicant,
			{},
			replicant.config,
			true,
			key
		))
		
		Replica.ReplicantRegistered:Fire(replicant, keyRef)
	else
		error("Replica.Register can only be called on the server")
	end
end

function Replica.Unregister(keyRef)
	local key
	if type(keyRef) == "string" then
		key = keyRef
		if IsInstanceGuid(key) then
			error("Cannot explicitly unregister instance-bound keys")
		end
	elseif type(keyRef) == "number" then
		key = keyRef
	elseif typeof(keyRef) == "Instance" then
		key = instanceGuidMap[keyRef]
		if not key then
			return
		end
	end
	
	if RunService:IsServer() then
		local replicator = Replicators:FindFirstChild(key)
		if replicator then
			replicator:Destroy()
		end
		
		local replicant = registry[key]
		if replicant ~= nil then
			Replica.ReplicantWillUnregister:Fire(replicant, keyRef)
			
			if typeof(keyRef) == "Instance" then
				guidInstanceMap[key] = nil
				instanceGuidMap[keyRef] = nil
				CollectionService:RemoveTag(keyRef, COLLECTION_TAG)
				
				if instanceGuidTrackers[keyRef] ~= nil then
					instanceGuidTrackers[keyRef]:Disconnect()
					instanceGuidTrackers[keyRef] = nil
				end
			end
			
			registry[key]:Destroy()
			registry[key] = nil
			
			Replica.ReplicantUnregistered:Fire(replicant, keyRef)
		end
	else
		error("Replica.Unregister can only be called on the server")
	end
end

function Replica.WaitForRegistered(keyRef, timeout)
	local replicant = Replica.GetRegistered(keyRef)
	if replicant ~= nil then
		return replicant
	end
	
	local thread = SafeCoro.Running()
	local gotReturnValue = false
	local conn = Replica.ReplicantRegistered:Connect(function(replicant, otherKey)
		if not gotReturnValue and otherKey == keyRef then
			gotReturnValue = true
			
			SafeCoro.Resume(thread, replicant)
		end
	end)
	
	if timeout ~= nil then
		FastSpawn(function()
			wait(timeout)
			if not gotReturnValue then
				gotReturnValue = true
				
				SafeCoro.Resume(thread, nil)
			end
		end)
	end

	local returnVal = SafeCoro.Yield()
	conn:Disconnect()

	if type(returnVal) == "table" and rawget(returnVal, "_isReplicant") == true then
		return returnVal
	else
		return nil
	end
end

function Replica.GetRegistered(keyRef)
	return registry[keyRef] or (instanceGuidMap[keyRef] and registry[instanceGuidMap[keyRef]])
end

Replica.Deserialize = Replicant.FromSerialized

Replica.ReplicantRegistered = Signal.new()
Replica.ReplicantWillUnregister = Signal.new()
Replica.ReplicantUnregistered = Signal.new()

-- Register replicants created on the server
if RunService:IsClient() then
	FastSpawn(function()
		script:WaitForChild("Replicators")
		local baseReplicantEvent = script:WaitForChild("_ReplicateBaseReplicant")
		local getGuidFunction = script:WaitForChild("_GetRegisteredGUID")
		
		-- We want to match instances tagged in CollectionService with string GUID keys.
		local collectionBuffer = {}
		local instanceGuidRegisteredSignal = Signal.new()
		local function MatchInstanceGuid(instance, guidKey, replicant)
			collectionBuffer[guidKey] = nil

			instanceGuidMap[instance] = guidKey
			guidInstanceMap[guidKey] = instance
			
			registry[guidKey] = replicant
			Replica.ReplicantRegistered:Fire(replicant, instance)
		end
		
		local function DeregisterReplicant(key)
			if not IsInstanceGuid(key) then
				local replicant = registry[key]
				if replicant ~= nil then
					Replica.ReplicantWillUnregister:Fire(replicant, key)
					
					replicant:Destroy()
					registry[key] = nil
					
					Replica.ReplicantUnregistered:Fire(replicant, key)
				end
			else
				local stillInBuffer = collectionBuffer[key]
				if stillInBuffer then
					stillInBuffer:Destroy()
					collectionBuffer[key] = nil
				else
					local replicant = registry[key]
					if replicant then
						local instance = guidInstanceMap[key]
	
						instanceGuidMap[instance] = nil
						guidInstanceMap[key] = nil
						
						Replica.ReplicantWillUnregister:Fire(replicant, key)
						
						registry[key]:Destroy()
						registry[key] = nil
					
						Replica.ReplicantUnregistered:Fire(replicant, instance)
					end
				end
			end
		end
		
		-- Collection service entry point
		local function handleCollectionInstance(instance)
			local guidKey = getGuidFunction:InvokeServer(instance)
			
			if guidKey then
				if collectionBuffer[guidKey] ~= nil then
					MatchInstanceGuid(instance, guidKey, collectionBuffer[guidKey])
				else
					local startTime = tick()
					repeat
						local replicant, key = instanceGuidRegisteredSignal:Wait()
						
						if key == guidKey then
							MatchInstanceGuid(instance, guidKey, replicant)
						end
					until key == guidKey or not instance:IsDescendantOf(game) or (tick() - startTime > INSTANCE_GUID_MATCHING_BUFFER_TIMEOUT)
				end
			end
		end
		CollectionService:GetInstanceAddedSignal(COLLECTION_TAG):Connect(handleCollectionInstance)
		for _, instance in pairs(CollectionService:GetTagged(COLLECTION_TAG)) do
			FastSpawn(handleCollectionInstance, instance)
		end
		
		-- Listen to the server for any registered keys
		baseReplicantEvent.OnClientEvent:Connect(function(key, serialized, config)
			-- Remove existing
			DeregisterReplicant(key)
			
			if serialized ~= nil then
				local replicant = Replicant.FromSerialized(serialized, config)
				
				local replicator = Replicators:WaitForChild(key, 20)
				if not replicator then return end
				
				replicant:_setContext(Context.new(
					replicant,
					{},
					replicant.config,
					true,
					key
				))
				
				if IsInstanceGuid(key) then
					-- Buffer instance keys and wait for corresponding instance to replicate
					collectionBuffer[key] = replicant
					instanceGuidRegisteredSignal:Fire(replicant, key)
				else
					-- For regular keys, register immediately
					registry[key] = replicant
					Replica.ReplicantRegistered:Fire(replicant, key)
				end
			end
		end)
	end)
else
	local baseReplicantEvent = Instance.new("RemoteEvent")
	baseReplicantEvent.Name = "_ReplicateBaseReplicant"
	baseReplicantEvent.Parent = script
	
	local getGuidFunction = Instance.new("RemoteFunction")
	getGuidFunction.Name = "_GetRegisteredGUID"
	getGuidFunction.Parent = script
	
	local sentInitialReplication = {}
	
	Replica.ReplicantRegistered:Connect(function(replicant, keyRef)
		local key
		if type(keyRef) == "string"
			or type(keyRef) == "number" then
			key = keyRef
		elseif typeof(keyRef) == "Instance" then
			key = instanceGuidMap[keyRef]
		end
		
		for _, client in pairs(game.Players:GetPlayers()) do
			if replicant:VisibleToClient(client) and sentInitialReplication[client] then
				baseReplicantEvent:FireClient(client, key, replicant:Serialize(key, client), replicant.config)
			end
		end
	end)
	
	Replica.ReplicantWillUnregister:Connect(function(replicant, keyRef)
		local key
		if type(keyRef) == "string"
			or type(keyRef) == "number" then
			key = keyRef
		elseif typeof(keyRef) == "Instance" then
			key = instanceGuidMap[keyRef]
		end
		
		for _, client in pairs(game.Players:GetPlayers()) do
			if replicant:VisibleToClient(client) and sentInitialReplication[client] then
				baseReplicantEvent:FireClient(client, key, nil)
			end
		end
    end)
    
    local function sendInitReplicationToClient(client)
        for key, replicant in pairs(registry) do
            if replicant:VisibleToClient(client) then
                baseReplicantEvent:FireClient(client, key, replicant:Serialize(key, client), replicant.config)
            end
        end
        sentInitialReplication[client] = true
    end
	
    game.Players.PlayerAdded:Connect(function(client)
        sendInitReplicationToClient(client)
    end)
    
    -- For any players already on the server at the time this module runs (as this can be required after players have joined)
    -- invoke initial replication of replicants
    for _, client in pairs(game.Players:GetPlayers()) do
        sendInitReplicationToClient(client)
    end
	
	game.Players.PlayerRemoving:Connect(function(client)
		sentInitialReplication[client] = nil
	end)
	
	getGuidFunction.OnServerInvoke = function(client, instance)
		if typeof(instance) == "Instance" then
			return instanceGuidMap[instance]
		end
	end
	
	-- Remove collection tags from cloned objects that are not registered
	CollectionService:GetInstanceAddedSignal(COLLECTION_TAG):Connect(function(instance)
		if not instanceGuidMap[instance] then
			CollectionService:RemoveTag(instance, COLLECTION_TAG)
		end
	end)
end

return Replica