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
