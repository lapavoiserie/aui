# Controls

## Button

Interactive button with a text label and an action.

```haxe
// With StateAction
new Button("Click me", count.inc())
new Button("-", count.dec())
new Button("Reset", count.setTo(0))
new Button("Toggle", flag.tog())
```

| Parameter | Type | Description |
|-----------|------|-------------|
| label | `String` | Button text |
| stateAction | `StateAction` (optional) | Action to perform on tap |

Generated Kotlin:

```kotlin
Button(onClick = { count++ }) {
    Text("Click me")
}
```

See [State & Actions](state/state-and-actions.md) for all available actions.

## TextField

Text input field bound to a `State<String>`.

```haxe
@:state var name:String = "";

new TextField("Enter your name", name)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| placeholder | `String` | Placeholder text |
| textState | `State<String>` (optional) | State to bind |

Generates an `OutlinedTextField` with two-way binding:

```kotlin
OutlinedTextField(
    value = name,
    onValueChange = { name = it },
    label = { Text("Enter your name") },
    modifier = Modifier.fillMaxWidth()
)
```

## Toggle

On/off switch bound to a `State<Bool>`.

```haxe
@:state var darkMode:Bool = false;

new Toggle("Dark mode", darkMode)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| label | `String` | Toggle label |
| isOnState | `State<Bool>` (optional) | State to bind |

Generates a `Row` with `Text` + `Switch`.

## Slider

Numeric slider bound to a `State<Float>`.

```haxe
@:state var volume:Float = 0.5;

new Slider(volume)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| valueState | `State<Float>` (optional) | State to bind |
