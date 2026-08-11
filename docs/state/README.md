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
3. Your `body()` reads and writes that cell as plain Haxe — `count.get()`, `count.set(...)` — and the renderer applies a declarative action the same way
4. Those reads happen *inside* composition, so Compose's snapshot system records them through the JVM frames Haxe emits, and any write — from a Compose handler or from pure Haxe logic — recomposes what read it

## What backs it

`State<T>` also extends [`rui.state.State`](https://lapavoiserie.github.io/rui/#/state),
the reactive core shared with the other La Pavoiserie backends (`sui`, `wui`, `cui`, `qui`).
The Compose `MutableState` is unchanged and **still what drives recomposition** — the shared
signal sits alongside it, not in front of it.

Concretely, each read does double duty: it registers a dependency for any `rui` effect *and*
returns the value from the `MutableState`, so a read inside a `@Composable` is tracked by
Compose exactly as before. Each write updates the shared core and then mirrors into the
`MutableState`, unconditionally — Compose applies its own structural-equality policy, and
the generated Kotlin writes back through this same `set()`, so short-circuiting would risk
desynchronising the two sides.

What this buys you: state can now be observed from plain Haxe, outside any `@Composable`,
via [`rui` effects](https://lapavoiserie.github.io/rui/#/signals) — useful for logic that
reacts to state without rendering.

`applyExternal(value)` is inherited and available for a value that comes *from* the platform
and must not be echoed back; aui does not use it yet, since generated Kotlin writes go
through `set()`.

See [State & Actions](state/state-and-actions.md) for full details.
