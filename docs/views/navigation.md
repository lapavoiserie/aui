# Navigation

## TabView

Bottom tab navigation with Material 3 NavigationBar.

```haxe
new TabView([
    new Tab("Home", "home", homeContent),
    new Tab("Settings", "settings", settingsContent)
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| tabs | `Array<Tab>` | Tab definitions |

### Tab

| Parameter | Type | Description |
|-----------|------|-------------|
| title | `String` | Tab label |
| icon | `String` | Icon name (see below) |
| content | `View` | Tab content |

### Available icons

| Icon name | Material Icon |
|-----------|--------------|
| `"home"` | Home |
| `"settings"`, `"gear"` | Settings |
| `"person"`, `"profile"` | Person |
| `"star"`, `"favorite"` | Star |
| `"search"` | Search |
| `"list"` | List |
| `"info"` | Info |
| `"add"`, `"plus"` | Add |
| `"edit"` | Edit |
| `"delete"`, `"trash"` | Delete |
| `"email"`, `"mail"` | Email |
| `"phone"`, `"call"` | Phone |

Generated Kotlin:

```kotlin
Scaffold(
    bottomBar = {
        NavigationBar {
            NavigationBarItem(
                selected = selectedTab == 0,
                onClick = { selectedTab = 0 },
                icon = { Icon(Icons.Filled.Home, contentDescription = "Home") },
                label = { Text("Home") }
            )
            // ...
        }
    }
) { innerPadding ->
    when (selectedTab) {
        0 -> { /* Home content */ }
        1 -> { /* Settings content */ }
    }
}
```

## NavigationStack

Stack-based navigation with route management.

```haxe
new NavigationStack(
    new VStack([
        new Text("Home"),
        new NavigationLink("Go to Detail", detailView)
    ])
)
```

Generates a `NavHost` with `composable` routes. Each `NavigationLink` destination is extracted into its own route.

## NavigationLink

Creates a button that navigates to a destination view.

```haxe
new NavigationLink("Details", new VStack([
    new Text("Detail Screen").font(FontStyle.HeadlineLarge)
]))
```

| Parameter | Type | Description |
|-----------|------|-------------|
| label | `String` | Link text |
| destination | `View` | Destination view |
