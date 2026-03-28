# Views

AUI provides 25+ view types that map to Jetpack Compose composables. All views extend `aui.View` and support modifier chaining.

## View categories

| Category | Views | Compose equivalent |
|----------|-------|-------------------|
| [Layout](views/layout.md) | VStack, HStack, ZStack, Spacer, ScrollView | Column, Row, Box, Spacer |
| [Text & Labels](views/text-and-labels.md) | Text, Text.withState, Image | Text, Icon |
| [Controls](views/controls.md) | Button, TextField, Toggle, Slider | Button, OutlinedTextField, Switch, Slider |
| [Lists & Iteration](views/lists-and-iteration.md) | ForEach, Section, LazyColumn | forEach, LazyColumn |
| [Navigation](views/navigation.md) | TabView, Tab, NavigationStack, NavigationLink | Scaffold+NavigationBar, NavHost |
| [Containers](views/containers.md) | Card, ProgressView, Divider, ConditionalView | Card, ProgressIndicator, Divider |

## Creating views

All views are created with `new`:

```haxe
new Text("Hello")
new VStack([child1, child2])
new Button("Click", someState.inc())
```

## Modifier chaining

Every view supports method chaining for modifiers:

```haxe
new Text("Styled")
    .font(FontStyle.HeadlineLarge)
    .bold()
    .foregroundColor(ColorValue.Blue)
    .padding(16)
```

See [Modifiers](modifiers.md) for the full list.
