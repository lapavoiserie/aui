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

In Compose:

```kotlin
Column {
    TabRow(selectedTabIndex = selected) {
        Tab(selected = 0 == selected, onClick = { /* select */ }, text = { Text("Home") })
        // one per tab
    }
    /* the selected tab's content */
}
```

A `TabView` keeps its tab labels beside its contents rather than among them, so
the source exposes them separately — the contents are the node's children, the
labels are read by index.

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
