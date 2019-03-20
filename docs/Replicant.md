# Replicant

Replicant is an Abstract class; it cannot be instantiated

The Replicant class is the base class from which Replica's main classes inherit.

In general, a Replicant has
- Some table that is wrapped
- A Get() and Set() implementation to get/set items in this table
- An optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument in the constructor that allows the Replicant's visibility to be controlled, regardless of where it is placed in the data tree. If a parent Replicant uses a different config, the descendant will override the parent's config whenever the `Config` argument is explicitly provided for the descendant replicant.

Some limitations of replicants:
- A Replicant **must** be registered, or placed as a direct descendant of another registered replicant in order for mutation functions such as Set() to properly replicate. If a replicant is not placed in the correct tree, Replica will raise an error upon attempting to use methods that can only be called in a registered context.
- A replicant **cannot** be placed inside of another non-replicant table and still function correctly.

```lua
-- BAD! MyArray is not a direct descendant of another replicant
local myData = Replica.Map.new({
    SomeKey = {
        MyArray = Replica.Array.new(),
    },
})
```

```lua
-- Good! MyArray is a descendant of another replicant
local myData = Replica.Map.new({
    SomeKey = Replica.Map.new({
        MyArray = Replica.Array.new(),
    }),
})
```

```lua
-- Good! MyArray is not a Replicant object.
-- Note, howerever, that mutating this table will NOT replicate it.
-- instead, myData:Set("SomeKey", { MyArray = { . . . } }) must be called,
-- and the entire table will be send through in the same buffer.
local myData = Replica.Map.new({
    SomeKey = {
        MyArray = {
        },
    },
})
```

# Methods

### `(unknown) Get((any) key)`

Gets the value at a given key if it exists. All Replicant objects wrap some form of table that this function accesses.

----

### `(void) Set((any) key, (any) value)`

Sets the value at a given key and replicates it if in the proper context. Specific classes may have restrictions on the types of keys or values that can be set.

For example, Map only allows string keys, and Array only allows sequential integer keys.

----

### `(void) Collate((function) callback)`

__Warning:__ Your callback should not yield when calling Collate

Calls a function within a collating context, which allows replication to be deferred until the function has finished execution.

Example of collation:
```lua
-- These calls will be replicated in separate buffers. This means the player will see a delay between when Coins updates and when Swag updates. playerData.OnUpdate will be fired twice.
playerData:Set("Coins", playerData:Get("Coins") - 10)
playerData:Set("Swag", playerData:Get("Swag") + 1)

-- These calls will be replicated in the same buffer; playerData.OnUpdate will only be fired once, and the client will see both values updated at the same time.
playerData:Collate(function()
    playerData:Set("Coins", playerData:Get("Coins") - 10)
    playerData:Set("Swag", playerData:Get("Swag") + 1)
end)
```

----

### `(void) Local((function) callback)`

__Warning:__ Your callback should not yield when calling Local

Calls a function within a local context, which allows changes to be made to the state without replication.

This should usually only be called on the client for predicting server-replicated state changes.

Example of local context calls:
```lua
-- BAD! These will error, because the client does not have permission to replicate playerData to the server
playerData:Set("Coins", playerData:Get("Coins") + 10)

-- Good! This will set "Coins" on the client only, which will be reset only when the server replicates an overridding value for Coins to the client.
playerData:Local(function()
    playerData:Set("Coins", playerData:Get("Coins") + 10)
end)
```

----

### `(table) Serialize([string] key)`

Serializes the Replicant object using the Replica format, which can be stored in data stores, used in HTTP requests, or sent through remotes. The `key` argument is optional, and can generally be ignored, as it is used internally for representing changes in the replication buffer

----

### `(void) MergeSerialized((table) serialized)`

Merges a serialized form of the Replicant. Old keys will be preserved, while new keys will be added or overwritten.

This can be used to allow backwards-compatible data structures that are saved in DataStores

Example (only saving portions of the playeData Map object:
```lua
-- Saving portions of playerData to the datastore
local dataStoreObject = {
    Persistent = playerData:Get("Persistent"):Serialize(),
    Private = playerData:Get("Private"):Serialize()
}
DataStore:SetAsync(player.UserId, dataStoreObject)

. . . 

-- Loading portions of playerData from the datastore
local dataStoreObject = DataStore:GetAsync(player.UserId)
local playerData = Replica.Map.new({
    Private = Replica.Map.new({
        -- Put player data defaults here
    }, {SubscribeAll = false, Whitelist = { player }})
    Persistent = Replica.Map.new({
        -- Put player data defaults here
    })
})

-- Overwrite saved data
if dataStoreObject ~= nil then
    if dataStoreObject.Persistent ~= nil then
        playerData:Get("Persistent"):MergeSerialized(dataStoreObject.Persistent)
    end
    if dataStoreObject.Private ~= nil then
        playerData:Get("Private"):MergeSerialized(dataStoreObject.Private)
    end
end
```

----

### `(table) GetConfig()`

Returns the current replication [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md)

----

### `(void) SetConfig((table) config)`

Changes the current replication config [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md)

----

### `(Signal) GetValueWillUpdateSignal((any) key)`

Similar to `Instance:GetPropertyChangedSignal()`, this will return a signal that fires _just prior_ to updating a given key from replication, or from a Set call in a Local context, similar to `Replicant.WillUpdate`

----

### `(Signal) GetValueOnUpdateSignal((any) key)`

Does the same thing as `GetValueWillUpdateSignal`, but fires _after_ a key has ben updated, similar to `Replicant.OnUpdate`

----

### `(boolean) VisibleToClient((Player) client)`

Returns true iff a player is subscribed to updates for this Replicant object.

----

### `(boolean) VisibleToAllClients()`

Returns true iff all clients are automatically subscribed to updates for this Replicant object.

----

### `(void) Inspect([number] maxDepth)`

Recursively prints the contents of a Replicant object to the output console in a human-readable format.

----

### `(void) Destroy()`

Disconnects all connected listeners and frees the object up for safe garbage collection. This is automatically called internally when `Set(replicantKey, nil)` or `Unregister(key)` are called.

----

# Events

### `(Signal) WillUpdate((boolean) isLocal)`

Called just prior to changing the Replicant's state from a replication update or a `Set` call in a Local context. If this came from a Local `Set` call, `isLocal` will be set to true.

----

### `(Signal) OnUpdate((boolean) isLocal)`

Called immediately after changing the Replicant's state from a replication update or a `Set` call in a Local context.

----

![](https://github.com/headjoe3/Replica/blob/master/Replicant.png)
