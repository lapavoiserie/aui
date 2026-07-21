# State Management

AUI provides reactive state that automatically updates your UI when values change. State is declared on your App class and backed at runtime by a Compose `MutableState` (through the `aui.state.StateBridge` runtime), so writes from anywhere — Compose handlers or pure Haxe logic — trigger recomposition.

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

1. `@:state var count:Int = 0` is transformed by `StateMacro` into a `State<Int>` field on the App instance
2. `State<T>` wraps a Compose `MutableState` created via `aui.state.StateBridge` (a Kotlin runtime object AUI copies into the generated project); the Haxe side only holds an opaque reference
3. The `ComposeGenerator` macro reads state as `app.count.get()` and writes it as `app.count.set(...)` — e.g. `count.inc()` becomes `app.count.set((app.count.get() as Int) + 1)`
4. Reads inside a `@Composable` are tracked by Compose's snapshot system, so any write — from a Compose handler or from pure Haxe logic — recomposes the UI

See [State & Actions](state/state-and-actions.md) for full details.
