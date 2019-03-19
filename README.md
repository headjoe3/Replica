# Replica

The Replica library is a Roblox Data Replication library, which uses Replicant objects (special replicated classes) to sync and replicate data changes to pre-configured clients in a controlled manner.

Replica allows you to control what portions of replicated data are visible to each client, as well as the packaging of data updates as they are replicated.

Replica also allows you to make local changes to the replicated data which are overwritten by server replication. This allows predictive state changes to be made on the client, even before the server has confirmed the predicted changes.

The core helper classes used to accomplish this are `Replicants`.
Currently, the following Replicant classes are supported:
* [`Array`](https://github.com/headjoe3/Replica/blob/master/docs/Array.md)
* [`Map`](https://github.com/headjoe3/Replica/blob/master/docs/Map.md)
* [`FactoredOr`](https://github.com/headjoe3/Replica/blob/master/FactoredOr/Array.md)
* [`FactoredNor`](https://github.com/headjoe3/Replica/blob/master/FactoredNor/Array.md)
* [`FactoredSum`](https://github.com/headjoe3/Replica/blob/master/docs/FactoredSum.md)


Replicants can be serialized using `replicant:Serialize(key)` and deserialized using `Replica:Deserialize(serialized)`. This allows Replicant data to easily be stored in DataStores.
The serialization format supports all Replica objects and most roblox data types.

# Documentation

See [documentation](https://github.com/headjoe3/Replica/blob/master/docs/Replica.md)

# Example

## Server
```lua
local Replica = require(game.ReplicatedStorage.Replica)

game:GetService("Players").PlayerAdded:Connect(function(player)
    -- Set up initial playerData state
    local playerData = Replica.Map.new({
        Coins = 0,
        -- Replicant objects
        Inventory = Replica.Array.new({
            "Foo",
            Replica.Array.new({}),
            "Bar",
        })
    })
    
    -- Replicant objects can be registered and de-registered to any key.
    -- Once they are registered, they will be replicated to all subscribed clients
    Replica.Register(player, playerData)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    Replica.Unregister(player)
end)

-- The server can make changes to the replicated data using setter functions, and it
-- will automatically be replicated to subscribed clients
while wait(1) do
    for _, player in pairs(game.Players:GetPlayers()) do
        local playerData = Replica.GetRegistered(player)
        if playerData ~= nil then
            -- Collated data changes will be sent to the client in one single update
            playerData:Collate(function()
                -- Getters and setters automatically replicate changes to Replicant data
                playerData:Set("Coins", playerData:Get("Coins") + 1)
                
                -- The Array object allows items to be inserted and removed at any
                -- position. Though I would recommend using a map instead,
                -- all array changes will be buffered and replicated to the clients,
                -- maintaining Replicant objects even when their position changes.
                -- within the playerData tree.
                local quxIndex = playerData:Get("Inventory"):IndexOf("Qux")
                if quxIndex == nil then
                    playerData:Get("Inventory"):Insert(1, "Qux")
                else
                    playerData:Get("Inventory"):Remove(quxIndex)
                end
            end)
        end
    end
end
```

## Client
```lua
local Replica = require(game.ReplicatedStorage.Replica)

-- You can guarantee the existance of a registered Replicant using WaitForRegistered
local playerData = Replica.WaitForRegistered(game.Players.LocalPlayer)

print("Player data loaded")

-- The client will receive data replication updates from the server
playerData.OnUpdate:Connect(function(isLocal)
    print("You have", playerData:Get("Coins"), "coins")
    print("You have", playerData:Get("Inventory"):Size(), "items in your inventory")
end)

-- Wait for character to load
local char = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()
local hum = char:FindFirstChildOfClass("Humanoid"); while not hum do char.ChildAdded:Wait() hum = char:FindFirstChildOfClass("Humanoid") end

-- The client can also make predictive state updates which will be overridden by
-- the server on the next update
hum.Jumping:Connect(function(isJumping)
    if isJumping then
        -- The Local function allows changes to be made without any replication
        -- implication. This is useful for things like UI, where you want to display
        -- changes predictively, even though you have not confirmed them with the
        -- server.
        playerData:Local(function()
            playerData:Set("Coins", 1000)
        end)
    end
end)
```