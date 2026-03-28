# CLI

AUI includes a command-line tool for building and running apps.

## Commands

| Command | Description |
|---------|-------------|
| `aui build` | Compile Haxe + build APK |
| `aui run` | Build + install + launch on device/emulator |
| `aui init <name>` | Create a new project |
| `aui clean` | Remove build artifacts |
| `aui version` | Show version |
| `aui help` | Show usage |

## Build options

| Flag | Description |
|------|-------------|
| `--release` | Build release APK (minified with R8) |
| `--verbose` | Show detailed command output |

## Build pipeline

`aui build` runs three stages:

1. **Haxe compilation** &mdash; Runs `haxe build.hxml`, which triggers the ComposeGenerator macro (generates `.kt` files) and the JVM target (generates `.jar`)
2. **Gradle wrapper** &mdash; Auto-detects a cached Gradle installation and bootstraps the wrapper if needed
3. **Gradle build** &mdash; Runs `./gradlew assembleDebug` (or `assembleRelease`)

## Device detection

`aui run` auto-detects `adb` by checking:

1. `$ANDROID_HOME/platform-tools/adb`
2. `~/Library/Android/sdk/platform-tools/adb`
3. `adb` in `$PATH`

## Project config

Projects are configured via `aui.json`:

```json
{
  "appName": "My App",
  "packageName": "com.example.myapp",
  "minSdk": 24,
  "targetSdk": 35,
  "compileSdk": 35
}
```

| Field | Description |
|-------|-------------|
| `appName` | Display name of the app |
| `packageName` | Android application ID |
| `minSdk` | Minimum Android API level |
| `targetSdk` | Target Android API level |
| `compileSdk` | Compile Android API level |
