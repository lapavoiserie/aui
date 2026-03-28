# Examples

AUI ships with 5 example apps, from basic to full-featured.

| Example | Level | Demonstrates |
|---------|-------|-------------|
| [Hello World](examples/hello-world.md) | Beginner | Text, layout, fonts, colors |
| [Counter](examples/counter.md) | Beginner | State, buttons, reactive text |
| [Navigation](examples/navigation.md) | Intermediate | Tabs, sections, NavigationBar |
| [Showcase](examples/showcase.md) | Intermediate | All widgets, visual effects, AlertDialog |
| [Todo App](examples/todo-app.md) | Advanced | Multi-screen, ConditionalView, view builders, Cards |

## Running an example

```bash
cd examples/counter
haxe build.hxml
cd android
gradle wrapper --gradle-version 8.11.1   # first time only
./gradlew assembleDebug
adb install -r app/build/outputs/apk/debug/app-debug.apk
```
