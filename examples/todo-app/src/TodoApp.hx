import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.ui.Divider;
import aui.ui.TextField;
import aui.ui.Card;
import aui.ui.ScrollView;
import aui.modifiers.ViewModifier;

class TodoApp extends App {
	@:state var taskCount:Int = 3;
	@:state var newTask:String = "";
	@:state var showDone:Bool = false;

	public function new() {
		super();
		appName = "Todo";
		packageName = "com.aui.todo";
	}

	public static function main() {
		new TodoApp();
	}

	override public function body():View {
		return new VStack([
			new Text("My Tasks").font(FontStyle.HeadlineLarge).bold(),
			Text.withState("{taskCount} tasks remaining").foregroundColor(ColorValue.Gray),
			new Divider(),
			new HStack(8, [
				new TextField("Add a task...", newTask),
				new Button("Add", taskCount.inc())
			]),
			new ScrollView([
				new Card([
					new HStack([
						new Text("Learn Haxe").padding(12),
						new Spacer(),
						new Button("Done", taskCount.dec()).foregroundColor(ColorValue.Green)
					])
				]),
				new Card([
					new HStack([
						new Text("Build with AUI").padding(12),
						new Spacer(),
						new Button("Done", taskCount.dec()).foregroundColor(ColorValue.Green)
					])
				]),
				new Card([
					new HStack([
						new Text("Ship to Play Store").padding(12),
						new Spacer(),
						new Button("Done", taskCount.dec()).foregroundColor(ColorValue.Green)
					])
				])
			]),
			new Spacer()
		]).padding();
	}
}
