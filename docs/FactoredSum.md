# FactoredSum

Sets the state of a double value to the summation of a set of factors
Factors are string keys mapped to number values

This can be used to store effects that stack, such as a "damage multiplier"

```lua
local Replica = require(Path.To.Replica)
local myFactoredSum = Replica.FactoredSum.new()

print(myFactoredSum:ResolveState()) -- 0

myFactoredSum:Set("Factor1", 1)

print(myFactoredSum:ResolveState()) -- 1

myFactoredSum:Set("Factor2", 2)

print(myFactoredSum:ResolveState()) -- 3

myFactoredSum:Set("Factor3", 5)

print(myFactoredSum:ResolveState()) -- 8

myFactoredSum:Set("Factor3", -13)

print(myFactoredSum:ResolveState()) -- -10
```

## [Read First: (inherits from Replicant)](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md)

# Constructor
### `Replica.FactoredSum.new((table) initial state, [table] config)`

Creates a new FactoredSum replicant with an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument for controlling replication

# Methods


### `(function, table) Pairs()`

Returns a pairs iterator for values in the FactoredSum. Example:
```lua
for factor, value in myData:Get("MyFactoredSum"):Pairs() do
    . . .
end
```

### `(void) Reset()`

Resets all enabled factors to "0" and replicates

### `(number) ResolveState()`

Returns the sum of all factors

# Events

### `(Signal) StateChanged((number) newState)`

Fired when the sum is changed to a new value