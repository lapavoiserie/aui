# State Management

AUI provides reactive state that automatically updates your UI when values change. State is declared on your App class and compiled to Compose's `mutableStateOf`.

## Quick reference

```haxe
class MyApp extends App {
    @:state var count:Int = 0;           // Integer state
    @:state var name:String = "";        // String state
    @:state var isOn:Bool = false;       // Boolean state
    @:state var progress:Float = 0.5;    // Float state

    override function body():View {
        return new VStack([
            Text.withState("Count: {count}"),     // Reads state
            new Button("+", count.inc()),           // Mutates state
            new TextField("Name", name),            // Two-way binding
            new Toggle("Switch", isOn),             // Two-way binding
            new ConditionalView(isOn,               // Conditional on state
                new Text("On!"),
                new Text("Off")
            )
        ]);
    }
}
```

## How it works

1. `@:state var count:Int = 0` is transformed by `StateMacro` into a `State<Int>` field
2. The `ComposeGenerator` macro detects `State<T>` fields and emits `var count by remember { mutableStateOf(0) }` in Kotlin
3. State mutations (`count.inc()`) generate direct Kotlin mutations (`count++`)
4. Compose's snapshot system automatically recomposes the UI when state changes

See [State & Actions](state/state-and-actions.md) for full details.
