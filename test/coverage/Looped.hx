import aui.App;
import aui.View;
import aui.ui.ForEach;
import aui.ui.Text;
import aui.ui.VStack;

/**
	A `ForEach` must not be demanded of the renderer.

	It has no rendering of its own: `aui.nui.ViewSource` splices its items into
	the parent's children, so the renderer only ever meets what the loop built.
	Asking it for a `"ForEach"` branch would be asking for dead code -- and that
	is what the coverage check did the day the dynamic path became the default,
	refusing an example the repository ships.
**/
class Looped extends App {
	@:state var colors:Array<String> = ["red", "green", "blue"];

	public function new() {
		super();
		appName = "Looped";
		packageName = "com.aui.looped";
	}

	public static function main() {}

	override public function body():View {
		return new VStack(null, null, [
			new Text("colors"),
			new ForEach(colors, color -> new Text(color))
		]);
	}
}
