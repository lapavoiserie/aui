# Components

A component is a reusable piece of view. AUI gives you two ways to write one,
and the difference between them is whether it needs **state of its own**.

## A method, when it has no state

If the piece is a function of its arguments, a method returning `View` is all it
takes — no base class, nothing to register. This is the common case and it is
covered in [View Builders](view-builders.md).

```haxe
function row(title:String, value:String):View {
    return new HStack(null, [
        new Text(title),
        new Spacer(),
        new Text(value)
    ]);
}
```

## `ViewComponent`, when it has state

When the piece owns state the rest of the app should not see, extend
`aui.ViewComponent` and override `body()`:

```haxe
import aui.ViewComponent;

class Counter extends ViewComponent {
    @:state var n:Int = 0;
    public var label:String;

    public function new(label:String) {
        super();
        this.label = label;
    }

    override public function body():View {
        return new HStack(null, [
            new Text(label + ": " + n.get()),
            new Button("+", n.inc())
        ]);
    }
}
```

Used like any other view:

```haxe
override public function body():View {
    return new VStack(null, null, [
        new Text("Above"),
        new Counter("clicks")
    ]);
}
```

`@:state` works inside a component exactly as it does in an `App` — the same
build pass runs on both — so each instance carries its own cell.

## How it renders

A component has **no rendering of its own**: it is *expanded* into whatever
`body()` returns. Walking the tree — through `nui`'s pull contract, or from a
devtool — you never meet the component, only the views it is made of.

That is also why a component is never checked against the renderer's vocabulary:
asking the renderer for a `Counter` branch would be asking it for dead code. A
`ForEach` is expanded the same way, into the siblings it yields.

## What a component is not

**It is not a new primitive.** Composing views AUI provides is unlimited;
introducing a *new kind of leaf* — one that maps to a Compose widget nothing
else produces — is not something a component can do.

```haxe
class Badge extends View {          // a new node type, not a component
    public function new(label:String) {
        super();
        viewType = "Badge";
    }
}
```

This is refused at compile time, naming the type and the ones that are covered:

```
src/MyApp.hx:32: The dynamic renderer cannot draw "Badge".
  Covered types: Button, Card, ConditionalView, Divider, HStack, ProgressView,
  SafeArea, ScrollView, Section, Slider, Spacer, TabView, Text, TextField,
  Toggle, VStack, ZStack.
  Add it to the when() in aui/runtime/DynamicComposable.kt.
```

A new leaf means teaching the renderer about it. Until AUI offers a registration
point for that, it is a change to the framework rather than to your app.

## Which build path

Nothing to choose: `aui` renders through the dynamic renderer, and a component
works. The static transpiler is [decommissioned](render-paths.md) and does not
render one — building with `-D aui_static` says so rather than dropping the
component silently, which is what it used to do.
