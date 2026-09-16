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

The template is resolved **at runtime**, against the registry every state joins
when it is constructed — so `{count}` finds the cell of that name and the string
Compose receives is already complete:

```kotlin
Text(text = "Count: 3")
```

A name that resolves to nothing stays as written: `{cont}` on screen says the
name is wrong, where an empty string would say nothing at all.

The text follows the state it names, and a write to it recomposes that `Text`
alone — see [what a write costs](../render-paths.md).

## Image

A picture, from where its `src` scheme says: `asset:` (the application's
assets), `data:` (PNG or JPEG), `file:`, `https:`. Decoded off the main thread
and cached; whatever cannot be drawn shows its `alt` in its place.

```haxe
new Image("asset:logo.png", "Farceur", {width: 120, fit: Cover})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| src | `String` | Where the picture comes from, by scheme |
| alt | `String` | What stands in for it, and what a screen reader says |
| options | `mui.ui.ImageOptions` | `width`, `height` (dp), `fit`: `Contain`, `Cover`, `Fill` |

## Icon

An icon from the shared vocabulary (`nui.Icons`), drawn as its Material icon
and tinted like text. Names are checked at compile time.

```haxe
new Icon("mic-off", "Muted")  // or, through mui, Icon(MicOff, "Muted")
```

## Divider

Horizontal line separator.

```haxe
new Divider()
```

Generates `HorizontalDivider()`.
