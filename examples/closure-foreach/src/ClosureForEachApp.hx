import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.ForEach;
import aui.state.State;
import aui.modifiers.ViewModifier;

/**
    Demonstrates the closure form of `ForEach`. The lambda parameter
    is a typed Haxe value bound by the enclosing closure, so
    `new Text(item)` inside the body translates to a Kotlin
    `Text(text = "$item", …)` referencing the loop variable.

    Before the fix in [Pign/aui#?] the TLocal handler returned an
    empty string for unbound lambda params, so the same code emitted
    `Text(text = "")`.
**/
class ClosureForEachApp extends App {
    @:state var colors:Array<String> = ["red", "green", "blue", "yellow"];

    public function new() {
        super();
        appName = "ClosureForEach";
        packageName = "com.aui.closureforeach";
    }

    public static function main() {
        new ClosureForEachApp();
    }

    override public function body():View {
        return new VStack([
            new Text("Closure-form ForEach demo").bold(),
            new ForEach(colors, color ->
                new Text(color)
            ),
        ]).padding();
    }
}
