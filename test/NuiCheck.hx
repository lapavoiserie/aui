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

		// --- deferred values: the grain LiveProps buys ---
		//
		// On the dynamic path the macro rewrites a view whose value is computed
		// from state: the node is built with a neutral value and carries the real
		// expression in `liveBuild`. That is what puts the state read inside the
		// composable displaying it rather than the one building the tree -- on a
		// device, body() replayed 0 times while the screen followed 0 -> 1 -> 2.
		var live = new LiveApp();
		var tree = live.body();
		var leaf = tree.children[0];

		check("a computed value is deferred", leaf.liveBuild != null);
		check("the built node does not carry the value",
			ViewNodeBridge.getText(leaf) != "", "empty");
		check("the value read is the real one", ViewNodeBridge.getText(leaf) == "n = 5",
			ViewNodeBridge.getText(leaf));

		// The point of the whole exercise: no rebuild, and the read follows.
		LiveApp.compte.set(9);
		check("a write changes the read with no tree rebuild",
			ViewNodeBridge.getText(leaf) == "n = 9", ViewNodeBridge.getText(leaf));

		check("a constant value is not deferred", tree.children[1].liveBuild == null);
		check("a container is never deferred", tree.liveBuild == null);

		// --- a component is described by what it renders ---
		//
		// A ViewComponent has no rendering of its own. If the source described it
		// as itself, every consumer of the pull contract would meet a node type
		// no renderer knows -- which is what a user's own view type used to do.
		var comp = new Row("composé");
		var cs = new ViewSource(comp);
		check("a component reports the type it expands to", cs.typeOf(comp) == "Text",
			cs.typeOf(comp));
		check("and its value is readable through the bridge",
			ViewNodeBridge.getText(comp) == "composé", ViewNodeBridge.getText(comp));

		var host = new VStack(null, null, [comp]);
		var hs = new ViewSource(host);
		check("a component nested in a tree is expanded too",
			hs.typeOf(hs.childAt(host, 0)) == "Text");

		// --- a ForEach is spliced into its parent, never drawn ---
		//
		// The static generator unrolled the loop while emitting Kotlin. Nothing
		// unrolled it for a consumer walking the tree, so the day the dynamic
		// renderer became the default a ForEach arrived as a childless node of a
		// type no renderer has a branch for. It is expanded here instead, like a
		// component -- the items become siblings, which is what the loop means.
		var items = new State<Array<String>>(["red", "green"], "items");
		var loop:View = new VStack(null, null, [
			new Text("head"),
			new aui.ui.ForEach(items, (c:String) -> new Text("item: " + c)),
			new Text("tail")
		]);
		var ls = new ViewSource(loop);
		check("a ForEach yields siblings, not a node of its own",
			ls.childCount(loop) == 4, Std.string(ls.childCount(loop)));
		check("the items keep their place among the siblings",
			ls.typeOf(ls.childAt(loop, 1)) == "Text"
			&& ViewNodeBridge.getText(ls.childAt(loop, 1)) == "item: red"
			&& ViewNodeBridge.getText(ls.childAt(loop, 3)) == "tail",
			ViewNodeBridge.getText(ls.childAt(loop, 1)));

		// Reading twice must not build the items twice: `childAt` is called once
		// per index, and an un-memoised expansion re-ran every builder each time.
		var built = 0;
		var counted:View = new VStack(null, null, [
			new aui.ui.ForEach(items, function(c:String) {
				built++;
				return new Text(c);
			})
		]);
		var ks = new ViewSource(counted);
		ks.childCount(counted);
		ks.childAt(counted, 0);
		ks.childAt(counted, 1);
		check("the items are built once per generation", built == 2, Std.string(built));

		// A new generation reads the list again: a source describes one tree.
		items.set(["red", "green", "blue"]);
		var after = new ViewSource(loop);
		check("a write to the list is seen by the next generation",
			after.childCount(loop) == 5, Std.string(after.childCount(loop)));

		// A list read must happen while the tree is being built, not when a
		// walker first reaches it. Compose records the read against whatever
		// composable is walking, so a lazily-read list belongs to a child of
		// DynamicRoot -- and a write to it recomposed that child, which got the
		// memo back from a generation nobody had rebuilt. On a device the new
		// row simply never appeared.
		var lazyItems = new State<Array<String>>(["a", "b"], "lazyItems");
		var lazyTree:View = new VStack(null, null, [
			new aui.ui.ForEach(lazyItems, (s:String) -> new Text(s))
		]);
		var reads = 0;
		var counting = new ViewSource(lazyTree);
		counting.classify();
		check("classify() reaches a list without anyone walking first",
			counting.childCount(lazyTree) == 2, Std.string(counting.childCount(lazyTree)));

		// Where *one* view is expected -- the root here -- there are no siblings
		// to become. Left alone it would have reached the renderer as a node type
		// with no branch, so it becomes the stack the static generator emitted.
		var bare:View = new aui.ui.ForEach(items, (c:String) -> new Text(c));
		var bs = new ViewSource(bare);
		check("a ForEach standing alone becomes a stack of its items",
			bs.typeOf(bare) == "VStack" && bs.childCount(bare) == 3,
			bs.typeOf(bare) + "/" + bs.childCount(bare));
		check("and it keeps one identity across the questions asked about it",
			bs.childAt(bare, 0) == bs.childAt(bare, 0));

		Sys.println(failures == 0 ? "\nall good" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}

/** A component: no rendering of its own, expanded into what body() returns. **/
class Row extends aui.ViewComponent {
	public var title:String;

	public function new(title:String) {
		super();
		this.title = title;
	}

	override public function body():View {
		return new Text(title);
	}
}

/**
	An app whose text is computed from state.

	`LiveProps` should defer it: `new Text("n = " + compte.get())` must not read
	the state while the tree is built. The constant beside it must be left alone,
	and the VStack holding them must never be deferred -- re-running a container's
	constructor would rebuild its children.
**/
class LiveApp extends aui.App {
	public static var compte = new State<Int>(5, "compte");

	public function new() {
		super();
	}

	override public function body():View {
		return new VStack(null, null, [
			new Text("n = " + compte.get()),
			new Text("constante")
		]);
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
