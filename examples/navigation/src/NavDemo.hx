import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.ui.Divider;
import aui.ui.TabView;
import aui.ui.Tab;
import aui.ui.Section;
import aui.modifiers.ViewModifier;

class NavDemo extends App {
	@:state var count:Int = 0;

	public function new() {
		super();
		appName = "Navigation Demo";
		packageName = "com.aui.navdemo";
	}

	public static function main() {
		new NavDemo();
	}

	override public function body():View {
		return new TabView([
			new Tab("Home", "home", new VStack([
				new Spacer(),
				new Text("Welcome to AUI").font(FontStyle.HeadlineLarge).bold(),
				new Text("A Haxe framework for Android").foregroundColor(ColorValue.Gray),
				new Spacer(),
				new Section("Counter", [
					Text.withState("Count: {count}").font(FontStyle.TitleLarge),
					new HStack(12, [
						new Button("-", count.dec()),
						new Button("+", count.inc())
					])
				]),
				new Spacer()
			]).padding()),
			new Tab("Settings", "settings", new VStack([
				new Spacer(),
				new Text("Settings").font(FontStyle.HeadlineLarge).bold(),
				new Spacer(),
				new Section("About", [
					new Text("AUI Framework v0.1.0"),
					new Text("Built with Haxe + Jetpack Compose").foregroundColor(ColorValue.Gray)
				]),
				new Spacer()
			]).padding())
		]);
	}
}
