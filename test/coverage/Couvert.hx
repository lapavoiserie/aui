import aui.App;
import aui.View;
import aui.ui.Button;
import aui.ui.Text;
import aui.ui.VStack;

/** N'utilise que des types que le renderer dynamique sait dessiner. **/
class Couvert extends App {
	@:state var n:Int = 0;

	public function new() {
		super();
		appName = "Couvert";
		packageName = "com.aui.couvert";
	}

	public static function main() {}

	override public function body():View {
		return new VStack(null, null, [
			new Text("compte : " + n),
			new Button("+", n.inc())
		]);
	}
}
