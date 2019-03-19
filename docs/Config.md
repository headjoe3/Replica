# Config

The "Config" is generally passed in as a second argument to a Replicant class constructor.

A config controls how a replicant will be replicated, and to which clients.
By default, all clients will be subscribed to replicant changes.

This is useful for hiding sensitive data from other clients

This is the default configuration:

```lua
--[[
	Default configuration for Replica objects (including other BaseReplica objects, such as Arrays).
	The configuration controls the behavior by which data is replicated between the server and client.
	
	Use these settings as a reference for creating your own Replica configuration
--]]

return {
	-- If true, changes made on the server will immediately be replicated to subscribed clients
	ServerCanSet = true,
	
	-- For most applications, this is unsafe, and should always be set to false
	ClientCanSet = false,
	
	-- If set to true, all clients will be subscribed to Replica changes (unless blacklisted); if set to false, no clients will be subscribed unless whitelisted.
	SubscribeAll = true,
	
	-- An explicit table of clients that will be subscribed to Replica changes when SubscibeAll is set to false
	Whitelist = {},
	
	-- An explicit table of clients that cannot be subscribed to Replica changes when SubscibeAll is set to true
	Blacklist = {},
}
```

## Making portions of data private

You can create a new configuration anywhere in the data tree, and all descendant replicants will inherit the config behavior

For example, if you wanted portions of the player data, you could set up a "Public" map and a "Private" map

```lua
local playerData = Replica.Map.new({
    Public = Replica.Map.new({}, {
        SubscribeAll = true,
    }),
    Private = Replica.Map.new({}, {
        SubscribeAll = false,
        Whitelist = { player },
    }),
})

playerData:Get("Public"):Set("Coins", 10) -- Replicated to all players
playerData:Get("Private"):Set("Secret", "I watch MLP") -- Replicated to one player only

Replica.Register(player, playerData)
```

Now, any updates within the "Public" tree will be visible to all players; however, updates within the "Private" tree will only be visible to the player that the data belongs to.