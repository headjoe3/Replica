# FactoredNor

Sets the state of a boolean value to "true" iff all factors in a set of factors are false.
Factors are string keys mapped internally to "true" or "nil" (using `myFactoredNor:Set(factor, false)` will set `factor` to `nil`)

This can be used for managing the state of things like player visibility, or whether actions such as jumping or sprinting can be performed.

```lua
local Replica = require(Path.To.Replica)
local myFactoredNor = Replica.FactoredNor.new()

print(myFactoredNor:ResolveState()) -- true

myFactoredNor:Set("Factor1", true)

print(myFactoredNor:ResolveState()) -- false

myFactoredNor:Set("Factor2", true)

print(myFactoredNor:ResolveState()) -- false

myFactoredNor:Set("Factor1", false)
myFactoredNor:Set("Factor2", false)

print(myFactoredNor:ResolveState()) -- true
```

## [Read First: (inherits from Replicant)](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md)

# Constructor
### `Replica.FactoredNor.new((table) initial state, [table] config)`

Creates a new FactoredNor replicant with an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument for controlling replication

# Methods


### `(function, table) Pairs()`

Returns a pairs iterator for values in the FactoredNor. Example:
```lua
for factor, isEnabled in myData:Get("MyFactoredNor"):Pairs() do
    . . .
end
```

### `(void) Reset()`

Sets all enabled factors to "false" and replicates

### `(void) Toggle((string) factor)`

Sets a factor's state to true if disabled, or false if enabled.

### `(boolean) ResolveState()`

Returns false iff at least one factor is enabled

# Events

### `(Signal) StateChanged((bool) newState)`

Fired when the state changes swaps false to true, or vice versa