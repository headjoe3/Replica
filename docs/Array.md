# Array

```lua
local Replica = require(Path.To.Replica)
local myArray = Replica.Array.new({1, 2, 3})
```

## [Read First: (inherits from Replicant)](https://github.com/headjoe3/Replica/blob/master/docs/Replicant.md)

# Constructor
### `Replica.Array.new((table) initial state, [table] config)`

Creates a new array replicant with an optional [Config](https://github.com/headjoe3/Replica/blob/master/docs/Config.md) argument for controlling replication

# Methods

### `(number) IndexOf((any) value)`

Finds the index of a given value in the Array

----

### `(function, table) Ipairs()`

Returns an ipairs iterator for values in the Array. Example:
```lua
for i, value in myData:Get("MyArray"):Ipairs() do
    . . .
end
```

----

### `(number) Size()`

Returns the size of the array

----

### `(void) Insert([number] index, (any) value)`

Inserts a value into the array and replicates changes. If an `index` argument is provided, all elements will be shifted over. Note that this could be costly, as every element shift must be replicated (each shift, however, will be collated)

----

### `(void) Remove((number) index)`

Removes an element at some index of the array, and replicates a shift over for the rest of the array's elements. Like `Insert`, this may be costly for larger arrays and shifts. It may be more beneficial to use `Pop` or [Replica.Map](https://github.com/headjoe3/Replica/blob/master/docs/Map.md) objects instead.

----

### `(void) Push((any) value)`

Inserts a value at the end of the array (equivalent to Insert if no index argument is provided) and replicates the change

----

### `(void) Pop()`

Removes the item at the end of the array and replicates the change.