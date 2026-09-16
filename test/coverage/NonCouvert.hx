import aui.App;
import aui.View;
import aui.ui.LazyColumn;
import aui.ui.Text;
import aui.ui.VStack;

/**
	Uses a type the dynamic renderer does not draw.

	The `LazyColumn` sits in a **helper method**, not in `body()`: a `taskItem(...)`
	is as much rendering as `body()` is, and not following the check into those
	would let through exactly what real apps write.
**/
class NonCouvert extends App {
	public function new() {
		super();
		appName = "NonCouvert";
		packageName = "com.aui.noncouvert";
	}

	public static function main() {}

	function illustration():View {
		return new LazyColumn([new Text("row")]);
	}

	override public function body():View {
		return new VStack(null, null, [new Text("input"), illustration()]);
	}
}
