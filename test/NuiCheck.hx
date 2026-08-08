import aui.View;
import aui.nui.ViewSource;
import aui.runtime.ViewNodeBridge;
import aui.state.State;
import aui.state.StateAction;
import aui.ui.Button;
import aui.ui.Text;
import aui.ui.VStack;

/**
	Checks the Haxe half of aui's dynamic renderer, on a plain JVM.

	## Why this exists

	Everything here is reached from **Kotlin**, by name, through the class
	loader. Nothing in Haxe calls it, so nothing in Haxe type-checks the way
	Kotlin uses it — and the failure mode is not a crash. `ViewSource` was first
	copied from `sui`, where a Button carries a closure in a field named
	`action`; aui has never had that field, so `Reflect.field` answered null and
	**every button would have done nothing at all, in silence**. A renderer that
	draws correctly and ignores every tap looks like a Compose problem.

	So these tests exercise the parts that no compiler can check: the field names
	read reflectively, and the meaning given to a `StateAction`.

	Run with `test/run.sh`. The Compose half is not involved — `aui.state.State`
	needs a JVM `aui.state.StateBridge`, and a stub in `test/stubs` provides one.
**/
class NuiCheck {
	static var failures = 0;

	static function check(what:String, ok:Bool, ?detail:String):Void {
		if (ok) {
			Sys.println('  ok   $what');
		} else {
			failures++;
			Sys.println('  FAIL $what' + (detail == null ? "" : '  -- $detail'));
		}
	}

	static function main() {
		Sys.println("aui — nui pull contract");

		var count = new State<Int>(0, "count");
		var flag = new State<Bool>(false, "flag");

		var text = new Text("counter");
		var plus = new Button("Plus", Increment(count));
		var toggle = new Button("Bascule", Toggle(flag));
		var mute = new Button("Sans action");
		var root:View = new VStack(null, null, [text, plus, toggle, mute]);

		var src = new ViewSource(root);

		// --- the walk ---
		check("the type is the bare name", src.typeOf(root) == "VStack", src.typeOf(root));
		check("children are counted", src.childCount(root) == 4, Std.string(src.childCount(root)));
		check("a child is reachable", src.typeOf(src.childAt(root, 1)) == "Button");

		// --- the fields read reflectively ---
		//
		// These are the ones a compiler cannot check: they are read by name.
		check("a Text's content is read", ViewNodeBridge.getText(text) == "counter",
			ViewNodeBridge.getText(text));
		check("a Button's label is read", ViewNodeBridge.getButtonLabel(plus) == "Plus",
			ViewNodeBridge.getButtonLabel(plus));

		// --- actions ---
		check("a button with an action has an id", src.actionId(plus) >= 0, Std.string(src.actionId(plus)));
		check("a button without one has none", src.actionId(mute) < 0, Std.string(src.actionId(mute)));
		check("an id is stable", src.actionId(plus) == src.actionId(plus));
		check("two buttons get distinct ids", src.actionId(plus) != src.actionId(toggle));

		// The heart of it: aui's actions are a declarative enum the static
		// generator translates to Kotlin. At runtime that translation does not
		// exist, so the source has to apply the enum itself.
		src.invokeAction(plus);
		check("Increment writes to the state", count.get() == 1, Std.string(count.get()));
		src.invokeAction(plus);
		check("Increment accumulates", count.get() == 2, Std.string(count.get()));

		src.invokeAction(toggle);
		check("Toggle flips the state", flag.get() == true, Std.string(flag.get()));

		src.invokeAction(mute);
		check("a button without an action breaks nothing", true);

		// Through the id, which is what a foreign consumer holds.
		src.invokeActionId(src.actionId(plus));
		check("invoking by id does the same", count.get() == 3, Std.string(count.get()));
		src.invokeActionId(-1);
		src.invokeActionId(999);
		check("an out-of-range id runs nothing", count.get() == 3);

		// SetValue / Decrement / Append, and the animated wrapper, which changes
		// how a change is shown -- never what is written.
		var direct = new Button("Fixe", SetValue(count, 40));
		new ViewSource(direct).invokeAction(direct);
		check("SetValue writes the value", count.get() == 40, Std.string(count.get()));

		var minus = new Button("Moins", Decrement(count, 8));
		new ViewSource(minus).invokeAction(minus);
		check("Decrement subtracts the given amount", count.get() == 32, Std.string(count.get()));

		var animated = new Button("Animé", Animated(Increment(count), Default));
		new ViewSource(animated).invokeAction(animated);
		check("Animated applies the inner action", count.get() == 33, Std.string(count.get()));

		var word = new State<String>("a", "word");
		var appender = new Button("Ajoute", Append(word, "b"));
		new ViewSource(appender).invokeAction(appender);
		check("Append concatenates", word.get() == "ab", word.get());

		// --- the optional modifier parameter ---
		//
		// `Padding()` means the default 16dp and `Padding(0)` means none, but
		// modifierFloat answers 0.0 to both. This is the difference the pull
		// contract cannot express, so aui's bridge answers it separately.
		var byDefault = new Text("d");
		byDefault.padding();
		var explicit = new Text("e");
		explicit.padding(0);

		var sd = new ViewSource(byDefault);
		var se = new ViewSource(explicit);
		check("a default padding reads as absent",
			sd.modifierType(byDefault, 0) == "Padding" && !sd.modifierHasParam(byDefault, 0, 0));
		check("an explicit padding of 0 reads as present",
			se.modifierType(explicit, 0) == "Padding" && se.modifierHasParam(explicit, 0, 0));
		check("yet both answer the same value",
			sd.modifierFloat(byDefault, 0, 0) == 0.0 && se.modifierFloat(explicit, 0, 0) == 0.0);

		// --- state templates ---
		//
		// `Text.withState` builds a template the *static* generator interpolates
		// into Kotlin. There is no Kotlin at runtime, so the bridge resolves the
		// names against the state registry. Without this the counter example
		// renders an empty string forever -- which reads as a renderer bug.
		var template = aui.ui.Text.withState("count: {count}");
		check("a template is resolved at runtime",
			ViewNodeBridge.getText(template) == "count: 33", ViewNodeBridge.getText(template));

		var twoNames = aui.ui.Text.withState("{count}/{word}");
		check("several names in one template",
			ViewNodeBridge.getText(twoNames) == "33/ab", ViewNodeBridge.getText(twoNames));

		// An unknown name stays as written: `{cont}` on screen says the name is
		// wrong, an empty string says nothing at all.
		var wrongName = aui.ui.Text.withState("x{cont}y");
		check("an unknown name stays visible",
			ViewNodeBridge.getText(wrongName) == "x{cont}y", ViewNodeBridge.getText(wrongName));

		var plain = aui.ui.Text.withState("sans accolade");
		check("a template with no name passes through",
			ViewNodeBridge.getText(plain) == "sans accolade", ViewNodeBridge.getText(plain));

		var unclosed = aui.ui.Text.withState("ouvert {count");
		check("an unclosed brace does not loop",
			ViewNodeBridge.getText(unclosed) == "ouvert {count", ViewNodeBridge.getText(unclosed));

		// --- views whose sub-views live outside `children` ---
		//
		// This is what made the todo example draw a blank screen: a walker
		// followed `childAt`, found nothing, and drew nothing. Reporting zero
		// children for a TabView is a lie to the pull contract, not a Compose
		// detail.
		var tabs = new aui.ui.TabView([
			new aui.ui.Tab("Tasks", "list", new Text("liste")),
			new aui.ui.Tab("Notes", "edit", new Text("notes"))
		]);
		var so = new ViewSource(tabs);
		check("a TabView counts its tabs", so.childCount(tabs) == 2,
			Std.string(so.childCount(tabs)));
		check("a TabView child is the tab's content",
			ViewNodeBridge.getText(so.childAt(tabs, 1)) == "notes");
		check("tab titles are readable", so.tabTitle(tabs, 0) == "Tasks", so.tabTitle(tabs, 0));
		check("an out-of-range tab index does not throw",
			so.childAt(tabs, 9) == null && so.tabTitle(tabs, 9) == "");

		var flag = new State<Bool>(true, "flag");
		var cond = new aui.ui.ConditionalView(flag, new Text("oui"), new Text("non"));
		var sc = new ViewSource(cond);
		check("a ConditionalView exposes both branches", sc.childCount(cond) == 2);
		check("the condition is read when asked", sc.conditionValue(cond) == true);
		flag.set(false);
		check("and follows the state, not the tree", sc.conditionValue(cond) == false);

		var noElse = new aui.ui.ConditionalView(flag, new Text("oui"));
		check("with no else branch, a single child",
			new ViewSource(noElse).childCount(noElse) == 1);

		var section = new aui.ui.Section("Work", [new Text("a"), new Text("b")]);
		check("a Section keeps its children", new ViewSource(section).childCount(section) == 2);
		check("and exposes its header", ViewNodeBridge.sectionHeader(section) == "Work");

		// --- the writes: the one direction the pull contract does not describe ---
		var entry = new State<String>("", "entry");
		var field = new aui.ui.TextField("Type here…", entry);
		check("the placeholder is read", ViewNodeBridge.fieldPlaceholder(field) == "Type here…");
		ViewNodeBridge.setFieldText(field, "bonjour");
		check("writing a field reaches the state", entry.get() == "bonjour", entry.get());
		check("and reads back through the bridge", ViewNodeBridge.fieldText(field) == "bonjour");

		var actif = new State<Bool>(false, "actif");
		var toggleView = new aui.ui.Toggle("Notifications", actif);
		ViewNodeBridge.setToggleValue(toggleView, true);
		check("toggling reaches the state", actif.get() == true);
		check("and reads back through the bridge", ViewNodeBridge.toggleValue(toggleView) == true);

		// Built without a state: the view is legal, so reading and writing it
		// must be survivable rather than throwing on a null cell.
		var stateless = new aui.ui.Toggle("Sans état");
		ViewNodeBridge.setToggleValue(stateless, true);
		check("a toggle with no state does not throw",
			ViewNodeBridge.toggleValue(stateless) == false);

		// --- what the bridge answers before setApp() ---
		//
		// Kotlin composes before the app is handed over, for at least one frame.
		check("the bridge answers before setApp()", ViewNodeBridge.getRoot() == null);
		check("and does not throw on a null node",
			ViewNodeBridge.getType(null) == "" && ViewNodeBridge.childCount(null) == 0);

		// --- the tree the bridge hands to Kotlin ---
		ViewNodeBridge.setApp(new DemoApp());
		var handed = ViewNodeBridge.getRoot();
		check("setApp() builds a tree", handed != null);
		check("the bridge describes that tree", ViewNodeBridge.getType(handed) == "VStack",
			ViewNodeBridge.getType(handed));

		// A rebuild re-runs body(): this is what makes a write visible, since
		// the tree holds values read when body() ran.
		var before = ViewNodeBridge.getText(ViewNodeBridge.getChild(handed, 0));
		DemoApp.counter.set(7);
		ViewNodeBridge.rebuild();
		var after = ViewNodeBridge.getText(ViewNodeBridge.getChild(ViewNodeBridge.getRoot(), 0));
		check("rebuild() makes the write visible", before != after, '"$before" -> "$after"');
		check("and renders the new value", after == "counter: 7", after);

		Sys.println(failures == 0 ? "\nall good" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

/** The smallest thing that is an app: a body() built from an observable. **/
class DemoApp extends aui.App {
	public static var counter = new State<Int>(0, "counter");

	public function new() {
		super();
	}

	override public function body():View {
		return new VStack(null, null, [
			new Text("counter: " + counter.get()),
			new Button("Plus", Increment(counter))
		]);
	}
}
