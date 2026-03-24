import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Spacer;
import aui.modifiers.ViewModifier;

class HelloWorld extends App {
	public function new() {
		super();
		appName = "Hello AUI";
		packageName = "com.aui.helloworld";
	}

	public static function main() {
		new HelloWorld();
	}

	override public function body():View {
		return new VStack([
			new Spacer(),
			new Text("Hello from AUI!").font(FontStyle.HeadlineLarge).bold(),
			new Text("Native Android, written in Haxe").foregroundColor(ColorValue.Gray),
			new Spacer(),
			new HStack([
				new Text("Powered by"),
				new Text("Jetpack Compose").foregroundColor(ColorValue.Blue).bold()
			]),
			new Spacer()
		]).padding();
	}
}
