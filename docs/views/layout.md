# Layout Views

## VStack

Vertical stack layout. Maps to Compose `Column`.

```haxe
new VStack([
    new Text("First"),
    new Text("Second"),
    new Text("Third")
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| content | `Array<View>` | Child views |

Generated Kotlin:

```kotlin
Column(horizontalAlignment = Alignment.CenterHorizontally) {
    Text("First")
    Text("Second")
    Text("Third")
}
```

## HStack

Horizontal stack layout. Maps to Compose `Row`.

```haxe
new HStack([
    new Text("Left"),
    new Spacer(),
    new Text("Right")
])

// With spacing
new HStack(12, [
    new Button("-", count.dec()),
    new Button("+", count.inc())
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| spacing | `Float` (optional) | Gap between children in dp |
| content | `Array<View>` | Child views |

The spacing parameter generates `Arrangement.spacedBy(12.dp)`.

## ZStack

Overlay stack layout. Maps to Compose `Box`.

```haxe
new ZStack([
    new Text("Background").opacity(0.3),
    new Text("Foreground")
])
```

## Spacer

Flexible empty space. In a VStack/HStack, it expands to fill available space.

```haxe
new VStack([
    new Text("Top"),
    new Spacer(),        // pushes content apart
    new Text("Bottom")
])
```

Generates `Spacer(modifier = Modifier.weight(1f))`.

## ScrollView

Vertically scrollable container.

```haxe
new ScrollView([
    new Text("Item 1"),
    new Text("Item 2"),
    // ... many items
])
```

Generates a `Column` with `Modifier.verticalScroll(rememberScrollState())`.

## SafeArea

Wraps content to respect system safe areas (status bar, navigation bar, display cutouts). Maps to a `Column` with `Modifier.safeDrawingPadding()`.

```haxe
new SafeArea([
    new Text("Title"),
    new VStack([
        new Text("Content is inset from system bars"),
    ]),
])
```

Generated Kotlin:

```kotlin
Column(modifier = Modifier.safeDrawingPadding()) {
    Text("Title")
    Column {
        Text("Content is inset from system bars")
    }
}
```

Use SafeArea as the outermost wrapper in your `body()` to keep content clear of notches, camera cutouts, and system navigation.
