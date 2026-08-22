# Being a `mui` backend

[`mui`](https://lapavoiserie.github.io/mui/) lets one source build for every
backend in this family. `aui` is the one that draws through Jetpack Compose.

## The conformance lives here

Under `aui/mui/` — one file per entry in
[`mui.Contract`](https://github.com/lapavoiserie/mui/blob/main/src/mui/Contract.hx).
A `typedef` where the signature already matches, a small subclass where it does
not:

```haxe
package aui.mui;

typedef View = aui.View;
```

`mui` holds **no branch for `aui`**, and none for any other backend. It states
the vocabulary as data, and one line in the build file resolves it:

```
-D mui_backend=aui
--macro mui.macros.Bind.all()
```

`Bind` defines `mui.ui.Button` as an alias of `aui.mui.Button`, then checks
every constructor against the contract — arity, optionality, argument types — and
names what does not match, at the top of the build rather than at first use.

It used to be the other way round: `mui` held 132 conditional branches and had to
know all six backends. Adding a seventh meant editing twenty-two files in a
repository that had nothing to learn from it.

## What else is ours

`aui/mui/init.hxml` is the build file `mui init` writes into a new project. It
lives here because what a build for this backend needs — which libraries, which
generator macro, which output — is ours to state, and `mui` had no way of keeping
six of them honest.

The façades are the *mapping* — which Compose widget a `mui` type becomes —
not the renderer's coverage. A type outside the dynamic renderer's vocabulary
refuses to compile, naming what is covered.

## Surfaces: the Glance widget

`@:surface(Glance)` becomes an Android **App Widget**. Jetpack Glance and
mui's `Glance` role share a name and nothing else — one is Android's widget
toolkit, the other is "read this at a glance", the role the Sailfish cover
fills too — and this is where they meet.

It is the **snapshot-detached** corner, and Android is what makes that corner
necessary rather than merely possible: the launcher draws the widget, from
`RemoteViews` built in our process when the *system* decides an update is due,
not when our state changes. There is no effect to reconcile and nobody to
reconcile it for. So the surface is *sampled*: `aui.mui.GlanceBridge` runs the
declaration's content thunk once, describes it as `nui` nodes, and
`nui.Snapshot.project` turns it into JSON — the same shape a Companion frame
carries over the network. One contract, two distances.

The sampled tree is kept in the widget's own state, which is what makes it a
snapshot rather than a cache: **the picture outlives the process that drew
it**. Kill the app and the home screen still shows what it last showed.
(Glance's `provideGlance` is a session, not a per-update callback — sampling
into a local value froze the widget at whatever the app held when the session
opened. Storing the picture is both the idiomatic fix and the honest model.)

A new picture is taken when the application leaves the foreground: what you
last saw in the app is what the home screen shows. A general "resample this
surface" call belongs in mui beside the role, and would serve WidgetKit the
same way (`reloadTimelines`); this is the first trigger, not the last word.

The widget's files — the receiver, its manifest entry, the provider XML, the
Jetpack Glance dependency — are emitted **only** for an application that
declares the surface. A build that never asked for a widget gets none, and
`GlanceBridge` itself lives in the mui facade, so a plain aui application has
no such thing.

### Tapping a widget

A `Button` in a Glance surface is a real button, and its closure runs. The
closure itself never crosses — it could not — so what the launcher holds is
an **action id**, taken from the snapshot's `actions` map, and a tap sends
that id back to `AuiGlanceAction` in our own process.

That process may have started *for this tap*, with an empty action table: the
launcher kept the picture, we kept nothing. So the callback **samples before
it invokes**, which rebuilds the table — and the id still resolves, because
ids are keyed by place: walking the same tree hands the same button the same
id. It is the property the first interactive Companion paid for, collected
here at a different distance. Then the action runs and a fresh picture is
pushed, so the widget shows what the tap did.

Nothing about the declaration is widget-specific:

```haxe
@:surface(Glance, optional)
function glance():View {
    return new VStack([
        new Text('Count: ${count.get()}'),
        new Button("+1", function() count.set(count.get() + 1)),
    ], 8);
}
```

That same declaration is a cover on Sailfish, where `qui.mui.CoverHost`
strips the callbacks at mount because a cover only displays — degradation the
*host* performs, which the declaration never has to know about.

Two limits worth stating rather than discovering:

- **A tree whose shape changed** between the launcher's picture and the tap —
  a list one item shorter — makes the id name something else or nothing, and
  the honest answer is the word `nui.ActionTable` already prints. Persisting
  the table beside the picture is what would close that, and is not done.
- **With no process alive**, the sample that warms the table constructs a
  fresh application, whose state is the application's initial state. The tap
  then acts on that, not on what you last saw. Persisting state across
  process death is the application's business; the framework does not pretend
  otherwise.

## Surfaces: the describer

aui signs `mui.surface.Describe` at construction (`aui.mui.App`), so an aui
application can serve the **detached corner**: a `@:surface(Companion)`
declaration projects over the network today — in a build that asked for it
with `-D mui_cafos`, without which the declaration does not compile — and a
widget snapshot (P4a) will ship the same trees. `aui.nui.Describe` turns aui views into `nui.Node`s with
the **canonical mui prop names** — `Text`/`text`, `Button`/`label`+`onClick`,
`Toggle`/`isOn`+`onToggle`, `TextInput`/`text`+`placeholder`+`onText`,
`Slider`/`value`+`min`+`max`+`onValue` — so an aui-served snapshot and a
cui-served one look the same on the wire, and one sink renders both.

Describing **samples**: every read goes through `ViewSource.resolveValue`
first (the truth lives behind the LiveProps thunk — the constructed node
holds neutral values), a `ConditionalView`'s condition is read live, a
`ForEach` splices its rows (reusing `ViewSource`'s expansion, one answer not
two), `Text.withState` templates are resolved against the state registry, and
a `TabView` flattens to its first tab — the selection lives on the Kotlin
side, so the Haxe tree cannot know which tab shows; said with a trace, not
guessed. A described button's tap does exactly what the dynamic renderer's
does: the declarative `StateAction`, else the `OnTapGesture` closure.

## See also

- [Adding a backend](https://lapavoiserie.github.io/mui/#/adding-a-backend) — the
  whole contract, and the two rules the six backends made necessary.
- [Backend support](https://lapavoiserie.github.io/mui/#/backend-support) — the
  generated table of what every backend answers for every type. It is generated
  by reading these very files.
