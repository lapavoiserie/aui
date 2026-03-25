import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.HStack;
import aui.ui.Button;
import aui.ui.Spacer;
import aui.ui.Divider;
import aui.ui.TextField;
import aui.ui.Toggle;
import aui.ui.Card;
import aui.ui.ScrollView;
import aui.ui.Section;
import aui.ui.ConditionalView;
import aui.ui.TabView;
import aui.ui.Tab;
import aui.modifiers.ViewModifier;

class TodoApp extends App {
	@:state var task1Done:Bool = false;
	@:state var task2Done:Bool = false;
	@:state var task3Done:Bool = false;
	@:state var task4Done:Bool = false;
	@:state var task5Done:Bool = false;
	@:state var task6Done:Bool = false;
	@:state var noteText:String = "";
	@:state var notifications:Bool = true;
	@:state var showConfirm:Bool = false;
	@:state var compactMode:Bool = false;

	public function new() {
		super();
		appName = "Todo";
		packageName = "com.aui.todo";
	}

	public static function main() {
		new TodoApp();
	}

	override public function body():View {
		return new TabView([
			// ---- TASKS TAB ----
			new Tab("Tasks", "list", new ScrollView([
				new HStack([
					new VStack([
						new Text("My Tasks").font(FontStyle.HeadlineLarge).bold(),
						new Text("Tap to mark as done").foregroundColor(ColorValue.Gray).font(FontStyle.BodyMedium)
					]),
					new Spacer()
				]).fillMaxWidth(),
				new Divider(),

				// --- Work section ---
				new Section("Work", [
					// Task 1
					new ConditionalView(task1Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Design new landing page").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task1Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Primary).cornerRadius(4).padding(4),
								new Text("Design new landing page").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task1Done.tog())
							]).padding(12)
						])
					),
					// Task 2
					new ConditionalView(task2Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Review pull requests").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task2Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Primary).cornerRadius(4).padding(4),
								new Text("Review pull requests").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task2Done.tog())
							]).padding(12)
						])
					),
					// Task 3
					new ConditionalView(task3Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Update dependencies").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task3Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Primary).cornerRadius(4).padding(4),
								new Text("Update dependencies").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task3Done.tog())
							]).padding(12)
						])
					)
				]),

				// --- Personal section ---
				new Section("Personal", [
					// Task 4
					new ConditionalView(task4Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Buy groceries").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task4Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Orange).cornerRadius(4).padding(4),
								new Text("Buy groceries").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task4Done.tog())
							]).padding(12)
						])
					),
					// Task 5
					new ConditionalView(task5Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Go for a run").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task5Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Orange).cornerRadius(4).padding(4),
								new Text("Go for a run").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task5Done.tog())
							]).padding(12)
						])
					),
					// Task 6
					new ConditionalView(task6Done,
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Green).cornerRadius(4).padding(4),
								new Text("Read a chapter").foregroundColor(ColorValue.Gray).font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Undo", task6Done.tog())
							]).padding(12)
						]).opacity(0.5),
						new Card([
							new HStack(8, [
								new Text("  ").background(ColorValue.Orange).cornerRadius(4).padding(4),
								new Text("Read a chapter").font(FontStyle.BodyLarge),
								new Spacer(),
								new Button("Done", task6Done.tog())
							]).padding(12)
						])
					)
				])
			]).padding()),

			// ---- NOTES TAB ----
			new Tab("Notes", "edit", new VStack([
				new Text("Quick Notes").font(FontStyle.HeadlineLarge).bold(),
				new Text("Jot down your thoughts").foregroundColor(ColorValue.Gray).font(FontStyle.BodyMedium),
				new Divider(),
				new Spacer(),
				new TextField("Write something...", noteText),
				new Spacer(),
				new Card([
					Text.withState("{noteText}").font(FontStyle.BodyLarge).padding(16).fillMaxWidth()
				]),
				new Spacer(),
				new Button("Clear", noteText.setTo("")),
				new Spacer()
			]).padding()),

			// ---- SETTINGS TAB ----
			new Tab("Settings", "settings", new ScrollView([
				new Text("Settings").font(FontStyle.HeadlineLarge).bold(),
				new Divider(),
				new Section("Preferences", [
					new Toggle("Enable notifications", notifications),
					new Toggle("Compact mode", compactMode)
				]),
				new Section("Data", [
					new Button("Reset all tasks", showConfirm.tog())
						.alert("Reset Tasks", showConfirm, "This will mark all tasks as not done.")
						.fillMaxWidth()
				]),
				new Section("About", [
					new Card([
						new VStack([
							new Text("Todo App").font(FontStyle.TitleLarge).bold(),
							new Text("Built with AUI Framework v0.1.0").foregroundColor(ColorValue.Gray).font(FontStyle.BodyMedium),
							new Divider(),
							new HStack(8, [
								new Text("Haxe").foregroundColor(ColorValue.Blue).font(FontStyle.BodyMedium).bold(),
								new Text("+").foregroundColor(ColorValue.Gray),
								new Text("Jetpack Compose").foregroundColor(ColorValue.Blue).font(FontStyle.BodyMedium).bold()
							]),
							new Text("Material Design 3").font(FontStyle.BodySmall).foregroundColor(ColorValue.Gray)
						]).padding(16)
					])
				])
			]).padding())
		]);
	}
}
