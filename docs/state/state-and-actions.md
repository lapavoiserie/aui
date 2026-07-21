# State & Actions

## Declaring state

Use the `@:state` metadata on your App class fields:

```haxe
class MyApp extends App {
    @:state var count:Int = 0;
    @:state var name:String = "";
    @:state var isEnabled:Bool = true;
    @:state var progress:Float = 0.5;
}
```

### Supported types

| Haxe type | Kotlin type | Default |
|-----------|-------------|---------|
| `Int` | `Int` | `0` |
| `Float` | `Float` | `0f` |
| `Bool` | `Boolean` | `false` |
| `String` | `String` | `""` |

Default values are extracted from the `@:state` declaration.

### How state is backed

Each `@:state` field becomes a `State<T>` on your **App instance**, backed at runtime by a Compose `MutableState` created through the `aui.state.StateBridge` runtime. Reads go through `app.count.get()` and writes through `app.count.set(...)`.

Because the cell lives on the app (not a Kotlin `remember` local), a write from **anywhere** — including pure Haxe logic invoked outside a `@Composable` — triggers recomposition. Reads inside a `@Composable` are tracked by Compose's snapshot system automatically. Haxe code never imports Compose types; it only sees the opaque `State<T>`.

## State actions

State actions are declarative mutations used in Button onClick handlers. They're methods on `State<T>`:

| Action | Usage | Generated Kotlin |
|--------|-------|-----------------|
| `inc()` | `count.inc()` | `app.count.set((app.count.get() as Int) + 1)` |
| `inc(n)` | `count.inc(5)` | `app.count.set((app.count.get() as Int) + 5)` |
| `dec()` | `count.dec()` | `app.count.set((app.count.get() as Int) - 1)` |
| `dec(n)` | `count.dec(5)` | `app.count.set((app.count.get() as Int) - 5)` |
| `setTo(val)` | `count.setTo(0)` | `app.count.set(0)` |
| `tog()` | `flag.tog()` | `app.flag.set(!(app.flag.get() as Boolean))` |

### Usage in Button

```haxe
new Button("+", count.inc())
new Button("Reset", count.setTo(0))
new Button("Toggle", isEnabled.tog())
```

## Text.withState

Display state values in text using `{braces}` placeholders:

```haxe
Text.withState("Count: {count}")
Text.withState("Hello, {name}!")
Text.withState("{count} items remaining")
```

Generated Kotlin uses `$` string interpolation over the app-backed state:

```kotlin
Text(text = "Count: ${app.count.get()}")
Text(text = "Hello, ${app.name.get()}!")
Text(text = "${app.count.get()} items remaining")
```

The text automatically updates when any referenced state variable changes.

## Two-way binding

TextField, Toggle, and Slider support two-way state binding:

```haxe
@:state var text:String = "";
@:state var enabled:Bool = false;

new TextField("Placeholder", text)   // types update text state
new Toggle("Label", enabled)          // switch updates enabled state
```

## Presentation modifiers with state

`.alert()` and `.sheet()` use `State<Bool>` to control visibility:

```haxe
@:state var showAlert:Bool = false;

new Button("Show", showAlert.tog())
    .alert("Title", showAlert, "Message text")
```

When `showAlert` becomes true, the AlertDialog appears. Dismissing it sets `showAlert` back to false.

## ConditionalView

Show different views based on a boolean state:

```haxe
@:state var isDone:Bool = false;

new ConditionalView(isDone,
    new Text("Completed!").foregroundColor(ColorValue.Green),
    new Button("Mark done", isDone.tog())
)
```
