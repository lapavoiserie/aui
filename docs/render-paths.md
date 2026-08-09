# Render paths

`aui` has had two ways to put a view on screen. Since this change there is one
by default, and the other is kept only so a build that depended on it still has
somewhere to go.

## The dynamic renderer — the path

The app runs. `body()` builds a Haxe view tree, and `DynamicComposable.kt` walks
it through [`nui`'s pull contract](https://lapavoiserie.github.io/nui/#/pull-mode),
composing as it goes.

Nothing about your app is decided at compile time, which is what buys the two
things that matter:

- **A component works.** `ViewComponent` is expanded by the tree reader, so a
  reusable piece with state of its own is just a view. See [Components](components.md).
- **Compose follows the Haxe reads.** `LiveProps` defers a view's values into
  thunks, so `n.get()` happens inside the composable that displays it. A write
  recomposes that node, not the screen.

The cost: the renderer has a vocabulary — the `when` in `DynamicComposable.kt` —
and a view type outside it is refused at compile time, naming the type. That
refusal is deliberate; drawing `?Badge` on a screen was the alternative.

## The static transpiler — decommissioned

The generator read `body()` from the typed AST at compile time and emitted
Kotlin ahead of time. Nothing of the view survived to runtime: no tree, no
reads to track, no reflection.

It is still here, behind `-D aui_static`, and building with it says what it is:

```
Warning : [AUI] the static Compose path is decommissioned and unmaintained.
  It does not support ViewComponent nor fine-grained recomposition.
  Drop -D aui_static to use the dynamic renderer.
```

### Why it was set aside rather than kept in parallel

Not because emitting Kotlin ahead of time is a bad idea — it is the reason a
transpiler exists, and it gives a build with no interpretation left in it. It
was set aside because **the two paths stopped rendering the same apps**:

| | Dynamic | Static |
|---|---|---|
| `ViewComponent` | expanded | refused — needs a composable carrying its state |
| Fine-grained recomposition | per node that read the state | whole screen |
| A view type it cannot draw | refused, naming it | refused, naming it |
| Where a view expression can come from | anywhere, it runs | must be translatable at compile time |

Every feature since the dynamic renderer landed has been dynamic-only, so
holding the two at parity meant writing each one twice — once against Compose,
once against the transpiler's translation of Haxe. Two implementations of one
promise drift, and the drift shows up as a screen that renders slightly wrong.

Keeping it costs one define and a few checks in `test/run.sh`, which is cheap
enough that removing it would be a decision about *aui's future*, not about this
change. Setting it aside is not that decision.

### `-D aui_dynamic`

Still accepted, and now a no-op: it names what the default already does. Passing
it together with `-D aui_static` is refused — one of the two is left over, and
guessing which builds something nobody asked for.

## Where the choice is made

In one place: [`aui.macros.RenderPath`](https://github.com/lapavoiserie/aui/blob/main/src/aui/macros/RenderPath.hx).
Everything that branches on the answer asks it there, so the deprecation warning
belongs to the build rather than to whichever branch happened to run first.
