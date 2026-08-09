import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;

/**
	A view type the application declared itself.

	It is not in `aui.ui`, which is exactly why it used to escape: the check
	watched our own package only, so a user's own node compiled clean and drew
	`?Badge` on the screen -- the silent failure this check exists to remove,
	left in place for the people it should protect.
**/
class Badge extends View {
	public function new(label:String) {
		super();
		viewType = "Badge";
		properties.set("label", label);
	}
}

class CustomPrimitive extends App {
	public function new() {
		super();
		appName = "CustomPrimitive";
		packageName = "com.aui.customprimitive";
	}

	public static function main() {}

	override public function body():View {
		return new VStack(null, null, [new Text("above"), new Badge("mine")]);
	}
}
