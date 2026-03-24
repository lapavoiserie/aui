import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.ZStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.ui.Divider;
import aui.ui.Toggle;
import aui.ui.TextField;
import aui.ui.Slider;
import aui.ui.ScrollView;
import aui.ui.Section;
import aui.ui.ConditionalView;
import aui.ui.TabView;
import aui.ui.Tab;
import aui.modifiers.ViewModifier;

class Showcase extends App {
	@:state var count:Int = 0;
	@:state var showAlert:Bool = false;
	@:state var darkMode:Bool = false;
	@:state var name:String = "";
	@:state var sliderVal:Float = 0.5;

	public function new() {
		super();
		appName = "AUI Showcase";
		packageName = "com.aui.showcase";
	}

	public static function main() {
		new Showcase();
	}

	override public function body():View {
		return new TabView([
			new Tab("Widgets", "list", new ScrollView([
				new Text("Widgets").font(FontStyle.HeadlineLarge).bold(),
				new Divider(),
				new Section("Text Input", [
					new TextField("Enter your name", name),
					new ConditionalView(darkMode,
						Text.withState("Hello, {name}!").font(FontStyle.TitleLarge).foregroundColor(ColorValue.Blue),
						Text.withState("Hello, {name}!").font(FontStyle.TitleLarge)
					)
				]),
				new Section("Counter", [
					Text.withState("Count: {count}").font(FontStyle.TitleLarge),
					new HStack(12, [
						new Button("-", count.dec()),
						new Button("Reset", count.setTo(0)),
						new Button("+", count.inc())
					])
				]),
				new Section("Toggle", [
					new Toggle("Dark Mode", darkMode)
				]),
				new Section("Alert", [
					new Button("Show Alert", showAlert.tog())
						.alert("Hello!", showAlert, "This alert was triggered from Haxe")
				]),
				new Spacer()
			]).padding()),
			new Tab("Modifiers", "star", new ScrollView([
				new Text("Visual Effects").font(FontStyle.HeadlineLarge).bold(),
				new Divider(),
				new Section("Shapes & Colors", [
					new HStack(8, [
						new Text("Rounded").padding(12).background(ColorValue.Blue).foregroundColor(ColorValue.White).cornerRadius(8),
						new Text("Border").padding(12).border(ColorValue.Red, 2).cornerRadius(8),
						new Text("Shadow").padding(12).background(ColorValue.White).shadow()
					]),
					new HStack(8, [
						new Text("50%").padding(12).background(ColorValue.Purple).foregroundColor(ColorValue.White).opacity(0.5),
						new Text("Scaled").padding(12).background(ColorValue.Green).foregroundColor(ColorValue.White).scaleEffect(1.2),
						new Text("Rotated").padding(12).background(ColorValue.Orange).foregroundColor(ColorValue.White).rotationEffect(15)
					])
				]),
				new Section("Layout", [
					new Text("Fill Width").padding().background(ColorValue.Gray).foregroundColor(ColorValue.White).fillMaxWidth(),
					new Text("Padded H").paddingHorizontal(32).paddingVertical(8).background(ColorValue.Blue).foregroundColor(ColorValue.White)
				]),
				new Spacer()
			]).padding()),
			new Tab("About", "info", new VStack([
				new Spacer(),
				new Text("AUI Framework").font(FontStyle.HeadlineLarge).bold(),
				new Text("v0.1.0").foregroundColor(ColorValue.Gray),
				new Spacer(),
				new Text("Write native Android apps in Haxe").font(FontStyle.BodyLarge),
				new Text("Powered by Jetpack Compose").foregroundColor(ColorValue.Gray),
				new Spacer(),
				new Text("23 view components").font(FontStyle.TitleMedium),
				new Text("30+ modifiers").font(FontStyle.TitleMedium),
				new Text("Reactive state management").font(FontStyle.TitleMedium),
				new Text("Tab & stack navigation").font(FontStyle.TitleMedium),
				new Spacer()
			]).padding())
		]);
	}
}
