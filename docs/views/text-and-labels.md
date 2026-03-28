# Text & Labels

## Text

Displays static text.

```haxe
new Text("Hello, world!")

// With modifiers
new Text("Title").font(FontStyle.HeadlineLarge).bold()
new Text("Subtitle").foregroundColor(ColorValue.Gray)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| content | `String` | Text to display |

### Text modifiers

These modifiers are translated to Text composable parameters (not `Modifier` chain):

| Modifier | Compose output |
|----------|---------------|
| `.font(FontStyle.HeadlineLarge)` | `style = MaterialTheme.typography.headlineLarge` |
| `.bold()` | `fontWeight = FontWeight.Bold` |
| `.italic()` | `fontStyle = FontStyle.Italic` |
| `.foregroundColor(ColorValue.Blue)` | `color = Color.Blue` |
| `.multilineTextAlignment(TextAlignment.Center)` | `textAlign = TextAlign.Center` |

## Text.withState

Displays text with reactive state interpolation. Variables in `{braces}` are replaced with state values.

```haxe
@:state var count:Int = 0;
@:state var name:String = "";

// In body():
Text.withState("Count: {count}")
Text.withState("Hello, {name}!")
```

Generated Kotlin:

```kotlin
Text(text = "Count: $count")
Text(text = "Hello, $name!")
```

The text automatically updates when the referenced state changes.

## Image

Displays an icon. Currently maps to Material Icons.

```haxe
new Image("star")
```

| Parameter | Type | Description |
|-----------|------|-------------|
| resourceName | `String` | Icon name |

## Divider

Horizontal line separator.

```haxe
new Divider()
```

Generates `HorizontalDivider()`.
