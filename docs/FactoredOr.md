# FactoredOr

Sets the state of a boolean value to "true" iff at least one factor in a set of factors is true.
Factors are string keys mapped internally to "true" or "nil" (using `myFactoredOr:Set(factor, false)` will set `factor` to `nil`)

This can be used for managing the state of things like player visibility, or whether actions such as jumping or sprinting can be performed.

```lua
local Replica = require(Path.To.Replica)
local myFactoredOr = Replica.FactoredOr.new()

print(myFactoredOr:ResolveState()) -- false

myFactoredOr:Set("Factor1", true)

print(myFactoredOr:ResolveState()) -- true

myFactoredOr:Set("Factor2", true)

print(myFactoredOr:ResolveState()) -- true

myFactoredOr:Set("Factor1", false)
myFactoredOr:Set("Factor2", false)

print(myFactoredOr:ResolveState()) -- false
```

## [Read First: (inherits from Replicant)](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md)

# Constructor
### `Replica.FactoredOr.new((table) initial state, [table] config)`

Creates a new FactoredOr replicant with an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument for controlling replication

# Methods


### `(function, table) Pairs()`

Returns a pairs iterator for values in the FactoredOr. Example:
```lua
for factor, isEnabled in myData:Get("MyFactoredOr"):Pairs() do
    . . .
end
```

### `(void) Reset()`

Resets all enabled factors to "false" and replicates

### `(void) Toggle((string) factor)`

Sets a factor's state to true if disabled, or false if enabled.

### `(boolean) ResolveState()`

Returns true iff at least one factor is enabled

# Events

### `(Signal) StateChanged((bool) newState)`

Fired when the state changes swaps false to true, or vice versa