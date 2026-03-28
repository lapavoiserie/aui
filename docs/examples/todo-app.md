# Todo App

A full-featured 3-tab todo app demonstrating the framework's capabilities.

## Source

```haxe
class TodoApp extends App {
    @:state var task1Done:Bool = false;
    @:state var task2Done:Bool = false;
    // ... more task states

    @:state var noteText:String = "";
    @:state var notifications:Bool = true;
    @:state var showConfirm:Bool = false;

    // View builder: reusable task card
    function taskItem(title:String, done:aui.state.State<Bool>, color:ColorValue):View {
        return new ConditionalView(done,
            // Done: faded with green indicator + Undo button
            new Card([
                new HStack(8, [
                    new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
                    new Text(title).foregroundColor(ColorValue.Gray),
                    new Spacer(),
                    new Button("Undo", done.tog())
                ]).padding(12)
            ]).opacity(0.5),
            // Active: colored indicator + Done button
            new Card([
                new HStack(8, [
                    new Text("  ").background(color).cornerRadius(4).padding(4),
                    new Text(title),
                    new Spacer(),
                    new Button("Done", done.tog())
                ]).padding(12)
            ])
        );
    }

    override function body():View {
        return new TabView([
            new Tab("Tasks", "list", new ScrollView([
                // Header
                new Text("My Tasks").font(FontStyle.HeadlineLarge).bold(),
                new Divider(),
                // Work section with purple indicators
                new Section("Work", [
                    taskItem("Design new landing page", task1Done, ColorValue.Primary),
                    taskItem("Review pull requests", task2Done, ColorValue.Primary),
                ]),
                // Personal section with orange indicators
                new Section("Personal", [
                    taskItem("Buy groceries", task4Done, ColorValue.Orange),
                    taskItem("Go for a run", task5Done, ColorValue.Orange),
                ])
            ]).padding()),

            new Tab("Notes", "edit", new VStack([
                new TextField("Write something...", noteText),
                new Card([ Text.withState("{noteText}").padding(16) ]),
                new Button("Clear", noteText.setTo(""))
            ]).padding()),

            new Tab("Settings", "settings", new ScrollView([
                new Toggle("Enable notifications", notifications),
                new Button("Reset all tasks", showConfirm.tog())
                    .alert("Reset Tasks", showConfirm, "This will mark all tasks as not done."),
                new Card([ /* About info */ ])
            ]).padding())
        ]);
    }
}
```

## What it shows

- **View builders** &mdash; `taskItem()` is a helper method that returns `View`, inlined at compile time. Eliminates repetition across 6 task cards.
- **ConditionalView** &mdash; Toggles between done (faded, green, "Undo") and active (colored, "Done") states per task.
- **State<Bool> toggling** &mdash; `done.tog()` flips the boolean, instantly swapping the ConditionalView.
- **TabView** &mdash; 3 tabs (Tasks, Notes, Settings) with Material 3 NavigationBar and icons.
- **TextField binding** &mdash; Live text preview in a Card below the input.
- **AlertDialog** &mdash; `.alert()` modifier with `showConfirm.tog()` trigger.
- **Cards, Sections, ScrollView** &mdash; Material containers and grouping.
- **Color-coded categories** &mdash; Purple for work, orange for personal.
