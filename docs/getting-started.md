# Getting Started

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Haxe | 4.3+ | Language compiler |
| hxjava | latest | JVM target support |
| Android SDK | API 24+ | Android build tools |
| Gradle | 8.x (auto-detected) | Build system |
| Java/JDK | 17+ | Kotlin/Gradle runtime |

## Install AUI

```bash
# Clone the repository
git clone https://github.com/AUI-Framework/aui.git

# Install hxjava if not already installed
haxelib install hxjava

# Build the CLI tool
cd aui
haxe -cp tools -cp src --main tools.cli.CLI -D jvm --jvm build/aui-cli.jar
```

## Create your first project

### Project structure

Create the following files:

```
MyApp/
  src/
    MyApp.hx        # Your app code
  build.hxml         # Haxe build config
  aui.json           # App config
```

### aui.json

```json
{
  "appName": "MyApp",
  "packageName": "com.example.myapp",
  "minSdk": 24,
  "targetSdk": 35,
  "compileSdk": 35
}
```

### build.hxml

```
-cp src
-cp /path/to/aui/src
-D jvm
--jvm build/app-logic.jar
--macro aui.macros.ComposeGenerator.register()
--main MyApp
```

### src/MyApp.hx

```haxe
import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.Spacer;
import aui.modifiers.ViewModifier;

class MyApp extends App {
    public function new() {
        super();
        appName = "My App";
        packageName = "com.example.myapp";
    }

    public static function main() {
        new MyApp();
    }

    override public function body():View {
        return new VStack([
            new Spacer(),
            new Text("Hello from AUI!").font(FontStyle.HeadlineLarge),
            new Text("Built with Haxe").foregroundColor(ColorValue.Gray),
            new Spacer()
        ]).padding();
    }
}
```

## Build and run

```bash
# Compile Haxe (generates Kotlin + JAR + Android project)
haxe build.hxml

# Bootstrap Gradle wrapper (first time only)
cd android
gradle wrapper --gradle-version 8.11.1
cd ..

# Build APK
cd android && ./gradlew assembleDebug && cd ..

# Install on device/emulator
adb install -r android/app/build/outputs/apk/debug/app-debug.apk
```

Or use the CLI:

```bash
aui build        # Compile + build APK
aui run          # Build + install + launch
```

## Build pipeline

The build happens in three stages:

1. **Haxe compilation** &mdash; `haxe build.hxml` runs the ComposeGenerator macro which emits `.kt` files, then compiles your app logic to a `.jar` via the JVM target
2. **Android project generation** &mdash; The GradleProject macro creates `build.gradle.kts`, `AndroidManifest.xml`, themes, and Gradle config on first build
3. **Gradle build** &mdash; `./gradlew assembleDebug` compiles the Kotlin + JAR into a signed APK

## What gets generated

After running `haxe build.hxml`, your project will contain:

```
MyApp/
  build/
    app-logic.jar                    # Haxe JVM output
  android/
    app/
      build.gradle.kts               # App build config
      src/main/
        AndroidManifest.xml           # Android manifest
        kotlin/com/aui/generated/
          MainActivity.kt             # Entry point
          MainScreen.kt               # Your UI (generated from body())
        res/values/
          themes.xml                  # Material theme
    build.gradle.kts                  # Root build config
    settings.gradle.kts               # Gradle settings
    gradle.properties                 # AndroidX, JVM config
```
