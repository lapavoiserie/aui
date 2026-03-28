# Lists & Iteration

## ForEach

Iterates over a collection to create views.

```haxe
new ForEach(items, function(item:String):View {
    return new Text(item);
})
```

| Parameter | Type | Description |
|-----------|------|-------------|
| items | `Dynamic` | Collection to iterate (typically `State<Array<T>>`) |
| builder | `Function` | View builder called for each item |

Generated Kotlin:

```kotlin
items.forEachIndexed { index, item ->
    Text(item)
}
```

## Section

Groups content under a styled header.

```haxe
new Section("Work", [
    new Text("Task 1"),
    new Text("Task 2")
])
```

| Parameter | Type | Description |
|-----------|------|-------------|
| header | `String` (optional) | Section title |
| content | `Array<View>` | Section children |

Generates a title in `MaterialTheme.typography.titleMedium` with primary color, followed by the children and a divider.

## LazyColumn

Efficient scrollable list for large datasets.

```haxe
new LazyColumn([
    new Text("Item 1"),
    new Text("Item 2"),
    new Text("Item 3")
])
```

Each child is wrapped in a `item { }` block for lazy loading.
