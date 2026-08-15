# Building on aui

`aui` is usually the top of the stack: your `App`, its `body()`, its views.
Sometimes something sits between — `mui`'s `App` and its view
types so one source can target four backends, and anyone writing a design system
over `aui` ends up in the same place.

That middle layer meets three rules that an application never has to think
about. All three were found by building `mui`'s kitchen sink on a device, and
each had failed in silence rather than loudly.

## The application is the leaf

Every class whose chain reaches `aui.App` is a candidate for "the app to build",
and a layer gives you two: yours, and the layer's. `ComposeGenerator`
instantiates the one **nobody extends**.

```
aui.App  ←  mui.App  ←  KitchenSink     builds KitchenSink
```

So a layer may declare `class App extends aui.App` freely. What it must not do
is leave two leaves: two application classes neither of which is extended is
ambiguous, and the build says so rather than picking quietly.

> Before this rule, the generator took the last candidate it saw — the
> intermediate — whose `body()` is the inherited default. The app drew
> `?EmptyView`, which reads as a renderer bug and is not one.

## An action may be a closure

`aui`'s own buttons carry a declarative `StateAction`:

```haxe
new Button("+", count.inc())
```

It is declarative because the transpiler had to translate it into Kotlin, and a
closure cannot be translated. A layer has no such enum to reach for — `mui`'s
button takes a Haxe closure — so a closure hung on the view counts as an action
too:

```haxe
new Button("Save").onTapGesture(() -> save(draft))
```

The dynamic renderer holds the live tree, so the closure stays reachable and is
called directly. A node carrying one reports an action id, which is what makes
the button *enabled*: before this, such a button was drawn greyed out, with
nothing anywhere to explain why.

This is the dynamic path only. The [static transpiler](render-paths.md) could
never have run a closure, which is why the declarative form exists.

## Values are read by name, from fields

The walk that describes a tree — [`aui.nui.ViewSource`](https://lapavoiserie.github.io/nui/#/pull-mode)
— reads a node's values by name, looking in `properties` first and then at the
node's own **field** of that name.

The field is where they usually are. `aui`'s views were written for a transpiler
that read `min`, `max`, `spacing` straight off the typed AST, so almost nothing
was ever put in the properties map. A view type you declare yourself may use
either; a plain field is enough.

```haxe
class Gauge extends View {
    public var min:Float;      // readable as floatProp(node, "min")
    public var max:Float;

    public function new(min:Float, max:Float) {
        super();
        viewType = "Gauge";    // and this is what the renderer switches on
        this.min = min;
        this.max = max;
    }
}
```

Two things follow from that last line:

- **`viewType` is the identity, not the class name.** A subclass reports its
  parent's unless it sets its own, which is why `mui.ui.TextInput` — an
  `aui.ui.TextField` — draws as a text field and is accepted by the coverage
  check.
- **A genuinely new `viewType` needs a renderer branch.** Without one the build
  is refused, naming the type. See [Components](components.md) for why that is a
  compile error rather than a placeholder on screen.
