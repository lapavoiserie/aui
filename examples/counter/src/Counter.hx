import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.ui.Divider;
import aui.modifiers.ViewModifier;

class Counter extends App {
	@:state var count:Int = 0;

	public function new() {
		super();
		appName = "Counter";
		packageName = "com.aui.counter";
	}

	public static function main() {
		new Counter();
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
