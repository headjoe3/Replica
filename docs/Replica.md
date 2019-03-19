# Replica Library

```lua
local Replica = require(Path.To.Replica)
```

# Replicant Classes

Replicant classes all inherit from [Replicant](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md). Their constructors include an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument which can be used to control how the replicant object is replicated if it is registered under a key, wherever it is nested in a registered tree.

* [Replica.Array](https://github.com/headjoe3/Replica/blob/master/docs/Array.md)
* [Replica.Map](https://github.com/headjoe3/Replica/blob/master/docs/Map.md)
* [Replica.FactoredOr](https://github.com/headjoe3/Replica/blob/master/FactoredOr/Array.md)
* [Replica.FactoredNor](https://github.com/headjoe3/Replica/blob/master/FactoredNor/Array.md)
* [Replica.FactoredSum](https://github.com/headjoe3/Replica/blob/master/docs/FactoredSum.md)

# Functions

### `(void) Replica.Register((any) key, (Replicant) replicant)`

Registers a replicant for data replication at some key.
The key will inevitably be converted to a string using `__tostring()` (escaped with "_ReplicatorFor" for non-string objects)

----

### `(void) Replica.Unregister((any) key)`

Removes a replicant at a given key and destroys it

----

### `(table) Replica.Deserialize((Replicant) replicant)`

Creates a replicant (or other serialized object) from the Replica serialization format obtained from `myReplica:Serialize([key])`. This supports most roblox data types, and is safe for data stores.

----

### `(Replicant or nil) Replica.WaitForRegistered((any) key, (number) timeout)`

Waits for a replica to be registered at a given key, or until a time out is reached if the optional `timeout` parameter is provided

----

### `(Replicant or nil) Replica.GetRegistered((any) key)`

Gets a registered replicant if it exists, or returns nil

----

# Events

These events use pseudo-RbxScriptSignal objects that act like regular roblox connections

----

### `(Signal) Replica.ReplicantRegistered ((Replicant) replicant, (string) key)`

Called right after a replicant is registered

### `(Signal) Replica.ReplicantWillUnregister ((Replicant) replicant, (string) key)`

Called right before a replicant is unregistered

----

### `(Signal) Replica.ReplicantUnregistered ((Replicant) replicant, (string) key)`

Called right after a replicant is unregistered. The provided replicant will be destroyed.