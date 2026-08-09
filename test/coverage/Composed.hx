import aui.App;
import aui.View;
import aui.ViewComponent;
import aui.ui.Text;
import aui.ui.VStack;

/** A component is expanded into what its body() returns, so it is never drawn
	and must never be demanded of the renderer. **/
class Row extends ViewComponent {
	public var title:String;

	public function new(title:String) {
		super();
		this.title = title;
	}

	override public function body():View {
		return new Text(title);
	}
}

class Composed extends App {
	public function new() {
		super();
		appName = "Composed";
		packageName = "com.aui.composed";
	}

	public static function main() {}

	override public function body():View {
		return new VStack(null, null, [new Row("composed")]);
	}
}
