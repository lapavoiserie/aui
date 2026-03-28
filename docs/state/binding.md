# Binding

Two-way binding between a state and a control. Used for passing state to child components or creating custom getter/setter pairs.

## From State

The most common usage — create a binding from an existing `State<T>`:

```haxe
var name = new State<String>("", "name");
var binding = Binding.fromState(name);

binding.get();       // reads name's value
binding.set("new");  // updates name's value
```

## Custom Binding

For computed or filtered bindings, pass explicit getter/setter functions:

```haxe
var binding = new Binding<String>(
    () -> name.get().toUpperCase(),
    (v) -> name.set(v.toLowerCase())
);
```

## API

### Constructor

```haxe
new Binding<T>(getter:() -> T, setter:T -> Void)
```

### Methods

| Method | Description |
|--------|-------------|
| `get():T` | Read the current value via the getter |
| `set(v:T):Void` | Write a new value via the setter |

### Factory

```haxe
Binding.fromState(state:State<T>):Binding<T>
```

Creates a binding that reads from `state.get()` and writes via `state.set()`.
