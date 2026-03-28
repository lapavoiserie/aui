# Modifiers

All views support modifier chaining. Modifiers return `this` so you can chain them:

```haxe
new Text("Hello")
    .font(FontStyle.HeadlineLarge)
    .bold()
    .foregroundColor(ColorValue.Blue)
    .padding(16)
    .background(ColorValue.Gray)
    .cornerRadius(8)
```

## Layout

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.padding()` | `?value:Float` | `Modifier.padding(16.dp)` |
| `.padding(n)` | `value:Float` | `Modifier.padding(n.dp)` |
| `.paddingHorizontal(n)` | `value:Float` | `Modifier.padding(horizontal = n.dp)` |
| `.paddingVertical(n)` | `value:Float` | `Modifier.padding(vertical = n.dp)` |
| `.frame(w, h)` | `?width, ?height:Float` | `Modifier.size(w.dp, h.dp)` |
| `.fillMaxWidth()` | | `Modifier.fillMaxWidth()` |
| `.fillMaxHeight()` | | `Modifier.fillMaxHeight()` |
| `.fillMaxSize()` | | `Modifier.fillMaxSize()` |
| `.offset(x, y)` | `x, y:Float` | `Modifier.offset(x.dp, y.dp)` |
| `.aspectRatio(r)` | `?ratio:Float` | `Modifier.aspectRatio(r)` |

## Typography

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.font(style)` | `FontStyle` | `style = MaterialTheme.typography.*` |
| `.bold()` | | `fontWeight = FontWeight.Bold` |
| `.italic()` | | `fontStyle = FontStyle.Italic` |
| `.multilineTextAlignment(align)` | `TextAlignment` | `textAlign = TextAlign.*` |

### FontStyle values

| AUI | Material Typography |
|-----|-------------------|
| `DisplayLarge` / `Medium` / `Small` | displayLarge/Medium/Small |
| `HeadlineLarge` / `Medium` / `Small` | headlineLarge/Medium/Small |
| `TitleLarge` / `Medium` / `Small` | titleLarge/Medium/Small |
| `BodyLarge` / `Medium` / `Small` | bodyLarge/Medium/Small |
| `LabelLarge` / `Medium` / `Small` | labelLarge/Medium/Small |

## Colors & Effects

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.foregroundColor(color)` | `ColorValue` | `color = Color.*` (Text parameter) |
| `.background(color)` | `ColorValue` | `Modifier.background(Color.*)` |
| `.opacity(f)` | `Float` | `Modifier.alpha(f)` |
| `.cornerRadius(r)` | `Float` | `Modifier.clip(RoundedCornerShape(r.dp))` |
| `.blur(r)` | `Float` | `Modifier.blur(r.dp)` |
| `.scaleEffect(s)` | `Float` | `Modifier.scale(s)` |
| `.rotationEffect(deg)` | `Float` | `Modifier.rotate(deg)` |
| `.shadow()` | | `Modifier.shadow(elevation = 4.dp)` |

### ColorValue values

| Value | Output |
|-------|--------|
| `Primary` | `MaterialTheme.colorScheme.primary` |
| `Secondary` | `MaterialTheme.colorScheme.secondary` |
| `Red`, `Blue`, `Green`, `Yellow` | `Color.Red`, etc. |
| `Orange`, `Purple`, `Pink` | `Color(0xFF...)` |
| `White`, `Black`, `Gray` | `Color.White`, etc. |
| `Transparent` | `Color.Transparent` |

## Border & Shape

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.border(color, ?width)` | `ColorValue, ?Float` | `Modifier.border(w.dp, Color.*)` |
| `.clipShape(shape)` | `ShapeType` | `Modifier.clip(...)` |

## Interaction

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.disabled(bool)` | `Bool` | Component `enabled` parameter |
| `.hidden()` | | `Modifier.alpha(0f)` |

## Presentation

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.alert(title, state, ?msg)` | `String, State<Bool>, ?String` | `AlertDialog(...)` |
| `.sheet(state, content)` | `State<Bool>, View` | `ModalBottomSheet(...)` |
| `.navigationTitle(title)` | `String` | TopAppBar title |

## Animation

| Modifier | Parameters | Compose output |
|----------|-----------|----------------|
| `.animation()` | `?AnimationCurve` | `Modifier.animateContentSize()` |
