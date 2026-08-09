# AUI

AUI is a framework for building **native Android apps in Haxe**. Your views are drawn by Jetpack Compose, producing genuine native Android applications with Material Design 3.

AUI is the Android counterpart of [SUI](https://github.com/Pign/sui), which targets Apple platforms (macOS, iOS, visionOS).

## How it works

```
Haxe source (.hx)
     |
     v
AUI macros (compile-time)
     |
     +---> JVM target ---------> app-logic.jar (your app, views included)
     |
     +---> GradleProject ------> Android project (manifest, MainActivity,
                                 |                DynamicComposable.kt)
                                 v
                            Gradle build ---> APK
                                 |
                                 v          at runtime: body() builds a tree,
                            DynamicRoot() --> Compose walks it through nui
```

1. You write your app in Haxe using the AUI view DSL
2. Haxe's JVM target compiles it — business logic *and* views — to a `.jar`
3. The `ComposeGenerator` macro emits the Android project around it: manifest,
   Gradle files, a `MainActivity` that hands the app to the tree reader, and the
   Compose renderer that walks the tree
4. Gradle builds the final APK

Your `body()` runs on the device. Compose sees the state it reads, so a write
recomposes the node that read it — see [Render paths](render-paths.md) for what
that buys, and for the decommissioned transpiler that used to emit your views as
Kotlin ahead of time.

## Features

| Feature | Details |
|---------|---------|
| Views | 25+ view types mapping to Compose composables |
| Modifiers | 30+ modifiers for layout, styling, effects |
| State | Reactive `@:state` with automatic Compose recomposition |
| Navigation | TabView with NavigationBar, NavigationStack with routes |
| Presentation | AlertDialog, BottomSheet via `.alert()`, `.sheet()` |
| View builders | Helper methods that return View are inlined at compile time |
| CLI | `aui build`, `aui run`, `aui init`, `aui clean` |
| Theming | Material Design 3 out of the box |

## Quick example

```haxe
class MyApp extends App {
    @:state var count:Int = 0;

    override function body():View {
        return new VStack([
            new Text("Hello from Haxe!").font(FontStyle.HeadlineLarge).bold(),
            Text.withState("Count: {count}").font(FontStyle.DisplayLarge),
            new HStack(12, [
                new Button("-", count.dec()),
                new Button("+", count.inc())
            ])
        ]).padding();
    }
}
```

This generates a native Android app with a reactive counter that updates in real time.
