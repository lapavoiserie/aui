# Navigation Demo

A two-tab app demonstrating TabView with NavigationBar, Sections, and counter state.

## Source

```haxe
class NavDemo extends App {
    @:state var count:Int = 0;

    override function body():View {
        return new TabView([
            new Tab("Home", "home", new VStack([
                new Text("Welcome to AUI").font(FontStyle.HeadlineLarge).bold(),
                new Section("Counter", [
                    Text.withState("Count: {count}"),
                    new HStack(12, [
                        new Button("-", count.dec()),
                        new Button("+", count.inc())
                    ])
                ])
            ]).padding()),

            new Tab("Settings", "settings", new VStack([
                new Text("Settings").font(FontStyle.HeadlineLarge).bold(),
                new Section("About", [
                    new Text("AUI Framework v0.1.0")
                ])
            ]).padding())
        ]);
    }
}
```

## What it shows

- **TabView + Tab** &mdash; Bottom navigation with Home and Settings icons
- **Section** &mdash; Grouped content with styled headers
- **State across tabs** &mdash; Counter state persists when switching tabs
- **Icon mapping** &mdash; `"home"` and `"settings"` map to Material Icons
