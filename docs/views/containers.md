# Containers

## Card

Material Design 3 elevated card.

```haxe
new Card([
    new HStack([
        new Text("Card Title").font(FontStyle.TitleMedium),
        new Spacer(),
        new Button("Action", someState.tog())
    ]).padding(16)
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| content | `Array<View>` | Card children |

Generates `Card(modifier = Modifier.fillMaxWidth()) { ... }`.

## ConditionalView

Conditionally shows one of two views based on a `State<Bool>`.

```haxe
@:state var isLoggedIn:Bool = false;

new ConditionalView(isLoggedIn,
    new Text("Welcome back!"),              // shown when true
    new Text("Please log in")               // shown when false
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| conditionState | `State<Bool>` | Boolean state to check |
| thenView | `View` | View when true |
| elseView | `View` (optional) | View when false |

Generated Kotlin:

```kotlin
if (isLoggedIn) {
    Text("Welcome back!")
} else {
    Text("Please log in")
}
```

This is the primary way to create dynamic UI that changes based on state. See the [Todo App](examples/todo-app.md) for a practical example.

## ProgressView

Activity indicator.

```haxe
// Indeterminate spinner
new ProgressView()

// Determinate progress bar
new ProgressView(progress)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| progressState | `State<Float>` (optional) | Progress value (0.0-1.0) |

Without a state, generates `CircularProgressIndicator()`. With a state, generates `LinearProgressIndicator(progress = { value })`.
