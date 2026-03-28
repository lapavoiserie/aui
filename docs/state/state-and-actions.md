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

Default values are extracted from the `@:state` declaration. For example, `@:state var count:Int = 42` generates `mutableStateOf(42)`.

## State actions

State actions are declarative mutations used in Button onClick handlers. They're methods on `State<T>`:

| Action | Usage | Generated Kotlin |
|--------|-------|-----------------|
| `inc()` | `count.inc()` | `count++` |
| `inc(n)` | `count.inc(5)` | `count += 5` |
| `dec()` | `count.dec()` | `count--` |
| `dec(n)` | `count.dec(5)` | `count -= 5` |
| `setTo(val)` | `count.setTo(0)` | `count = 0` |
| `tog()` | `flag.tog()` | `flag = !flag` |

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

Generated Kotlin uses `$` string interpolation:

```kotlin
Text(text = "Count: $count")
Text(text = "Hello, $name!")
Text(text = "$count items remaining")
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
