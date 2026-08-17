# aui

Build **native Android apps in Haxe**. Your views are drawn by Jetpack Compose
with Material Design 3 — genuine Android applications, not a web view and not a
canvas.

```haxe
import aui.App;
import aui.View;
import aui.ui.*;

class Counter extends App {
	@:state var count:Int = 0;

	public function new() {
		super();
		appName = "Counter";
		packageName = "com.aui.counter";
	}

	override public function body():View {
		return new VStack([
			new Text("Counter").font(FontStyle.HeadlineLarge).bold(),
			Text.withState("{count}").font(FontStyle.DisplayLarge),
			new HStack(16, [
				new Button("-", count.dec()),
				new Button("+", count.inc())
			])
		]).padding();
	}
}
```

Abridged from `examples/counter`.

## How it runs

Haxe compiles to a JVM jar, and Gradle builds the APK around it. `body()` runs
on the device and produces a view tree that a Compose renderer walks — so a
state write reaches the composables that read it, at Compose's own granularity.

An earlier design transpiled `body()` into Kotlin ahead of time. That transpiler
is [decommissioned](https://lapavoiserie.github.io/aui/#/render-paths); the page
says what replaced it and why.

## Getting started

```bash
haxelib git aui https://github.com/lapavoiserie/aui
haxelib run aui init MyApp
cd MyApp && haxelib run aui run
```

Needs Haxe 4.3+, a JDK 17, and the Android SDK.

## Native capabilities

Android APIs beyond the view vocabulary live in
[`kui`](https://lapavoiserie.github.io/kui/), keyed by operating system. A
capability reaching Android through `aui` carries a `gradle` payload — Kotlin
sources, Maven coordinates, manifest permissions — which `aui` renders into the
generated project, compiling the Kotlin where it lives rather than copying it.

## Part of La Pavoiserie

`aui` is one backend of [`mui`](https://lapavoiserie.github.io/mui/), which gives
an application one view vocabulary across six of them —
[`sui`](https://github.com/lapavoiserie/sui) for Apple platforms,
[`wui`](https://github.com/lapavoiserie/wui) for Windows,
[`cui`](https://github.com/lapavoiserie/cui) for the terminal, and others. The
same `body()` runs on all of them.

## Documentation

<https://lapavoiserie.github.io/aui/>

## Licence

MIT.
