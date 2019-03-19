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
local Replicators = script.Replicators

local Replicant = require(script.Replicant)
local Context = require(script.Context)
local Signal = require(script.Signal)
local SafeCoro = require(script.SafeCoro)
local FastSpawn = require(script.FastSpawn)

local function anyKeyToString(key)
	if type(key) ~= "string" then
		return "_ReplicatorFor" .. tostring(key)
	end
	
	return key
end

local Replica = {}
local registry = {}

Replica.Array = require(script.Replicants.Array)
Replica.Map = require(script.Replicants.Map)
Replica.FactoredOr = require(script.Replicants.FactoredOr)
Replica.FactoredNor = require(script.Replicants.FactoredNor)
Replica.FactoredSum = require(script.Replicants.FactoredSum)

function Replica.Register(key, replicant)
	key = anyKeyToString(key)
	
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
			Replica.Unregister(key)
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
		
		Replica.ReplicantRegistered:Fire(replicant, key)
	else
		error("Replica.Register can only be called on the server")
	end
end

function Replica.Unregister(key)
	key = anyKeyToString(key)
	
	if RunService:IsServer() then
		local replicant = registry[key]
		if replicant ~= nil then
			Replica.ReplicantWillUnregister:Fire(replicant, key)
			
			replicant:Destroy()
			registry[key] = nil
		end
		
		local replicator = Replicators:FindFirstChild(key)
		if replicator then
			replicator:Destroy()
		end
		
		Replica.ReplicantUnregistered:Fire(replicant, key)
	else
		error("Replica.Unregister can only be called on the server")
	end
end

function Replica.WaitForRegistered(key, timeout)
	key = anyKeyToString(key)
	if timeout ~= nil and type(timeout) ~= "number" then
		error("Bad argument #2 for Replica.WaitForRegistered (number expected, got " .. typeof(timeout) .. ")")
	end
	
	local replicant = registry[key]
	if replicant ~= nil then
		return replicant
	end
	
	local thread = SafeCoro.Running()
	local gotReturnValue = false
	local conn = Replica.ReplicantRegistered:Connect(function(replicant, otherKey)
		if not gotReturnValue and otherKey == key then
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

function Replica.GetRegistered(key)
	key = anyKeyToString(key)
	
	return registry[key]
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
		
		baseReplicantEvent.OnClientEvent:Connect(function(key, serialized, config)
			-- Remove existing
			local replicant = registry[key]
			if replicant ~= nil then
				Replica.ReplicantWillUnregister:Fire(replicant, key)
				
				replicant:Destroy()
				registry[key] = nil
				
				Replica.ReplicantUnregistered:Fire(replicant, key)
			end
			
			if serialized ~= nil then
				local replicant = Replicant.FromSerialized(serialized, config)
				
				local replicator = Replicators:WaitForChild(key, 20)
				if not replicator then return end
				
				registry[key] = replicant
				replicant:_setContext(Context.new(
					replicant,
					{},
					replicant.config,
					true,
					key
				))
				
				Replica.ReplicantRegistered:Fire(replicant, key)
			end
		end)
		
		-- Send initial request to get all replicants
		baseReplicantEvent:FireServer()
	end)
else
	local baseReplicantEvent = Instance.new("RemoteEvent")
	baseReplicantEvent.Name = "_ReplicateBaseReplicant"
	baseReplicantEvent.Parent = script
	
	local sentInitialReplication = {}
	
	Replica.ReplicantRegistered:Connect(function(replicant, key)
		for _, client in pairs(game.Players:GetPlayers()) do
			if replicant:VisibleToClient(client) and sentInitialReplication[client] then
				baseReplicantEvent:FireClient(client, key, replicant:Serialize(key), replicant.config)
			end
		end
	end)
	
	Replica.ReplicantUnregistered:Connect(function(replicant, key)
		for _, client in pairs(game.Players:GetPlayers()) do
			if replicant:VisibleToClient(client) and sentInitialReplication[client] then
				baseReplicantEvent:FireClient(client, key, nil)
			end
		end
	end)
	
	game.Players.PlayerAdded:Connect(function(client)
		for key, replicant in pairs(registry) do
			if replicant:VisibleToClient(client) then
				baseReplicantEvent:FireClient(client, key, replicant:Serialize(key), replicant.config)
			end
		end
		sentInitialReplication[client] = true
	end)
	
	game.Players.PlayerRemoving:Connect(function(client)
		sentInitialReplication[client] = nil
	end)
end

return Replica