# Factored value example

This example demonstrates the use of the FactoredOr, FactoredNor, and FactoredSum types, as well as the use of private-visibility data through the [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md).

Run this code in a Start Server + 2 Players test

## Server

```lua
local Replica = require(game.ReplicatedStorage.Replica)

game:GetService("Players").PlayerAdded:Connect(function(player)
    local playerData = Replica.Map.new({
        Or = Replica.FactoredOr.new(),
        Nor = Replica.FactoredNor.new(),
        -- This configuration makes the Sum only visible to the player that the
        -- playerData belongs to
        Sum = Replica.FactoredSum.new({}, { SubscribeAll = false, Whitelist = {player} }),
    })
    
    -- These should fire on the server output only when the state has changed value
    playerData:Get("Or").StateChanged:Connect(function(...)
        print("Or state changed", ...)
    end)
    playerData:Get("Nor").StateChanged:Connect(function(...)
        print("Nor state changed", ...)
    end)
    playerData:Get("Sum").StateChanged:Connect(function(...)
        print("Sum state changed", ...)
    end)
    
    Replica.Register(player, playerData)
end)

game:GetService("Players").PlayerRemoving:Connect(function(player)
    Replica.Unregister(player)
end)

local keys = {"a", "b", "c"}

while wait(2) do
    for _,player in pairs(game.Players:GetPlayers()) do
        local playerData = Replica.GetRegistered(player)
        if playerData then
            playerData:Collate(function()
                local key = keys[math.random(1, #keys)]
                -- The Or and Nore states should always resolve to the opposite
                -- of each other, since they always toggle the same keys.
                playerData:Get("Or"):Toggle(key)
                playerData:Get("Nor"):Toggle(key)
                -- The Sum state resolve to a random value between 0 and 3
                playerData:Get("Sum"):Set(key, math.random())
            end)
        end
    end
end
```

## Client

```lua
local Replica = require(game.ReplicatedStorage.Replica)

-- Note that we are reading Player1's data, so if Player2 joins, they will
-- see the same data with values in Sum omitted.
local playerData = Replica.WaitForRegistered(game.Players.Player1)

print("Player data loaded")

playerData.OnUpdate:Connect(function()
    print("UPDATE")
    for key, factorMap in playerData:Pairs() do
        print("   ", key .. ":", factorMap:ResolveState())
    end
end)
```