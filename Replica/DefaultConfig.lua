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
	
	-- If set to true, all clients will be subscribed to Replica changes (unless blacklisted)
	SubscribeAll = true,
	
	-- An explicit table of clients that will be subscribed to Replica changes (unless blacklisted)
	Whitelist = {},
	
	-- An explicit table of clients that cannot be subscribed to Replica changes
	Blacklist = {},
}