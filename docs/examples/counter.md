# Counter

A reactive counter app demonstrating state management.

## Source

```haxe
import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.modifiers.ViewModifier;

class Counter extends App {
    @:state var count:Int = 0;

    public static function main() { new Counter(); }

    public function new() {
        super();
        appName = "Counter";
        packageName = "com.aui.counter";
    }

    override public function body():View {
        return new VStack([
            new Spacer(),
            new Text("Counter").font(FontStyle.HeadlineLarge).bold(),
            new Spacer(),
            Text.withState("{count}").font(FontStyle.DisplayLarge),
            new Spacer(),
            new HStack(16, [
                new Button("-", count.dec()),
                new Button("+", count.inc())
            ]),
            new Spacer()
        ]).padding();
    }
}
```

## What it shows

- **`@:state var count:Int = 0`** &mdash; Declares reactive state, generates `var count by remember { mutableStateOf(0) }`
- **`Text.withState("{count}")`** &mdash; Displays state with automatic updates, generates `Text(text = "$count")`
- **`count.inc()` / `count.dec()`** &mdash; State actions in Button onClick, generates `count++` / `count--`
- **`new HStack(16, [...])`** &mdash; Horizontal row with 16dp spacing

Tapping the +/- buttons updates the count in real time thanks to Compose's reactive recomposition.
