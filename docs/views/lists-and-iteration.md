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

A `ForEach` is not a thing on screen: it is a loop that yields siblings. The
source runs the builder and splices the results into the parent, so Compose sees
them as ordinary children — there is no `ForEach` node and no case for one:

```kotlin
Column {
    Text("first")     // the loop's rows, in place
    Text("second")
}
```

Adding to or removing from the list changes the tree's shape, so it rebuilds;
see [what a write costs](../render-paths.md).

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
