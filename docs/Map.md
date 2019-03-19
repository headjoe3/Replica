# Map

A Map can map string keys to any value.
For the sake of replication, only string keys are allowed.

```lua
local Replica = require(Path.To.Replica)
local myMap = Replica.Map.new({ Coins = 1, Inventory = Replica.Array.new() })
```

## [Read First: (inherits from Replicant)](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md)

# Constructor
### `Replica.Map.new((table) initial state, [table] config)`

Creates a new Map replicant with an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument for controlling replication

# Methods


### `(function, table) Pairs()`

Returns a pairs iterator for values in the Map. Example:
```lua
for key, value in myData:Get("MyMap"):Pairs() do
    . . .
end
```