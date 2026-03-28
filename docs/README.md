# AUI

AUI is a framework for building **native Android apps in Haxe**. It compiles your Haxe source code into Jetpack Compose Kotlin, producing genuine native Android applications with Material Design 3.

AUI is the Android counterpart of [SUI](https://github.com/Pign/sui), which targets Apple platforms (macOS, iOS, visionOS).

## How it works

```
Haxe source (.hx)
     |
     v
AUI macros (compile-time)
     |
     +---> ComposeGenerator ---> Generated .kt (Composables)
     |
     +---> JVM target ---------> app-logic.jar (bytecode)
     |
     +---> GradleProject ------> Android project (build.gradle.kts, manifest)
                                       |
                                       v
                                  Gradle build ---> APK
```

1. You write your app in Haxe using the AUI view DSL
2. The `ComposeGenerator` macro walks your `body()` method at compile time and emits Kotlin `@Composable` functions
3. Haxe's JVM target compiles your business logic to a `.jar`
4. Gradle builds the final APK from the generated Kotlin + JAR

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
