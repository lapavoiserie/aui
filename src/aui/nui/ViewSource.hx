package aui.nui;

import nui.NodeSource;
import aui.View;
import aui.state.StateAction;

/**
	Describes a `aui` view tree through
	[nui's pull contract](https://lapavoiserie.github.io/nui/#/pull-mode).

	The node handle is `aui.View` itself: aui builds a live Haxe tree on the JVM,
	so nothing needs copying — the same choice `sui` and `cui` made.

	## What it is for

	This is how an aui app is drawn: `runtime/DynamicComposable.kt` walks the
	tree through these methods, so what a consumer of the contract sees and what
	Compose draws are the same description. It is written against the shared
	contract rather than a private accessor set, which is what `sui` ended up
	with — two answers to almost the same question, free to drift.

	It also decides what the renderer never has to know about. A node with no
	rendering of its own is expanded here: a `ViewComponent` into its `body()`
	(see `resolve`), a `ForEach` into the siblings it yields (see `childrenOf`).
	A renderer branch for either would be dead code.
**/
class ViewSource implements NodeSource<View> {
	final _root:View;
	final _actions:Array<View>;

	/**
		Walk the whole tree once, so every lazy part has been read by the time
		this returns.

		Expansion is lazy: a `ForEach`'s list is read when the walk reaches it.
		Under Compose that read is recorded against whichever composable is
		walking — a *child* of `DynamicRoot`, not `DynamicRoot` itself. So a
		write to the list recomposed that child, which asked `childrenOf` again
		and got the memo from a generation that had not been rebuilt: the new row
		never appeared, and nothing said why.

		Forcing the walk here puts the read inside the scope that calls
		`rebuild()`, so a write to a list rebuilds the tree, as a write to
		anything the tree's shape depends on must.
	**/
	public function classify():Void {
		visit(_root, 0);
	}

	function visit(n:View, depth:Int):Void {
		// A tree deep enough to reach this is a cycle, not a view.
		if (n == null || depth > 512) return;
		var count = childCount(n);
		for (i in 0...count) visit(childAt(n, i), depth + 1);
	}

	/** Expanded child lists, one generation of the tree — see `childrenOf`. **/
	var _children:haxe.ds.ObjectMap<View, Array<View>>;

	/** `ForEach` nodes standing where one view is expected — see `resolveWalked`. **/
	var _wrapped:haxe.ds.ObjectMap<View, View>;

	public function new(root:View) {
		_root = root;
		_actions = [];
	}

	public function root():View
		return _root;

	/**
		The tree is rebuilt by re-running the app's `body()`; the caller replaces
		the root, so a source describes one generation of the tree.
	**/
	public function rebuild():Void {}

	public function typeOf(n:View):String {
		n = resolveWalked(n);
		if (n == null) return "";
		var vt = n.viewType;
		if (vt == null) return "";
		// "aui.ui.VStack" -> "VStack": the contract's discriminant is the bare
		// type name, which is what a host switches on.
		var dot = vt.lastIndexOf(".");
		return dot >= 0 ? vt.substr(dot + 1) : vt;
	}

	/**
		aui has no notion of a sibling key yet, so identity is positional.

		Returning `null` is the contract's own answer for that, not a gap papered
		over: a host that rebuilds identity from scratch will recreate a control
		that merely moved. The day sui's lists carry keys, this is the one place
		to say so.
	**/
	public function keyOf(n:View):Null<String>
		return null;

	/**
		The children a consumer can walk.

		Some aui views keep their sub-views **outside** `children` -- `TabView`
		holds `Tab`s, `ConditionalView` holds a then/else pair. Reporting zero
		children for those is a lie to the pull contract, and it is what made the
		todo example draw a blank screen: a walker followed `childAt` and found
		nothing to draw.

		The classes are left alone -- the static generator reads their fields
		directly -- and the *description* is corrected here, which is what a
		source is for. Any consumer benefits, not just Compose.
	**/
	public function childCount(n:View):Int {
		n = resolveWalked(n);
		if (n == null) return 0;

		var tabs = tabsOf(n);
		if (tabs != null) return tabs.length;

		if (n.viewType == "ConditionalView") {
			return Reflect.field(n, "elseView") == null ? 1 : 2;
		}

		return childrenOf(n).length;
	}

	public function childAt(n:View, index:Int):View {
		n = resolveWalked(n);
		if (n == null || index < 0) return null;

		var tabs = tabsOf(n);
		if (tabs != null) return index < tabs.length ? tabs[index].content : null;

		if (n.viewType == "ConditionalView") {
			return switch (index) {
				case 0: cast Reflect.field(n, "thenView");
				case 1: cast Reflect.field(n, "elseView");
				case _: null;
			};
		}

		var children = childrenOf(n);
		return index >= children.length ? null : children[index];
	}

	/**
		The node a walker should read, for a node it reached by itself.

		`resolve` expands a component; this also covers a `ForEach` that sits
		where **one** view is expected -- the root, a tab's content, a
		conditional's branch. In a child list a `ForEach` becomes siblings
		(`childrenOf`), but a slot has no siblings to become, and the answer that
		does not lose the items is the stack the static generator emitted there:
		a `Column`.

		Memoised, because a walker asks `typeOf` then `childCount` then `childAt`
		about the same node, and a fresh wrapper each time would hand Compose a
		new identity on every question.
	**/
	function resolveWalked(n:View):View {
		var resolved = resolve(n);
		if (resolved == null || resolved.viewType != "ForEach") return resolved;

		if (_wrapped == null) _wrapped = new haxe.ds.ObjectMap();
		var cached = _wrapped.get(resolved);
		if (cached != null) return cached;

		var items = forEachItems(resolved);
		var stack:View = new aui.ui.VStack(null, null, items == null ? [] : items);
		_wrapped.set(resolved, stack);
		return stack;
	}

	/**
		A node's children, with every `ForEach` among them replaced by the views
		it produces.

		A `ForEach` is not a thing on screen: it is a loop that yields siblings.
		The static generator unrolled it while emitting Kotlin, which is why it
		never needed a description here -- and why, the day the dynamic renderer
		became the path, a `ForEach` reached it as a childless node of a type it
		had no branch for.

		Splicing it into the parent, rather than teaching the renderer a
		`"ForEach"` branch, is the same answer `ViewComponent` gets: a node with
		no rendering of its own is expanded before any consumer sees it. It also
		keeps the loop *out* of the renderer's vocabulary, where a branch would
		have had to reproduce the parent's layout scope to place the items as
		siblings rather than inside a box of their own.

		The items are read here, when the consumer asks -- under Compose that is
		inside the composition doing the asking, so a write to the list
		recomposes it and nothing above.
	**/
	function childrenOf(n:View):Array<View> {
		if (n.children == null || n.children.length == 0) return [];

		// Memoised per generation: `childAt` is called once per index, and
		// expanding on each call would re-run every item's builder n times.
		// The tree is rebuilt by replacing the source, so nothing here goes
		// stale -- see `ViewNodeBridge.rebuild`.
		if (_children == null) _children = new haxe.ds.ObjectMap();
		var cached = _children.get(n);
		if (cached != null) return cached;

		var out:Array<View> = [];
		var expanded = false;
		for (child in n.children) {
			var items = forEachItems(child);
			if (items == null) {
				out.push(child);
			} else {
				expanded = true;
				for (item in items) out.push(item);
			}
		}

		var result = expanded ? out : n.children;
		_children.set(n, result);
		return result;
	}

	/** The views a `ForEach` yields, or null for anything else. **/
	static function forEachItems(n:View):Null<Array<View>> {
		if (n == null || n.viewType != "ForEach") return null;

		var builder:Dynamic = Reflect.field(n, "builder");
		if (builder == null || !Reflect.isFunction(builder)) return [];

		// The items arrive either as the collection itself or as the `State`
		// holding it -- `@:state var colors` reads back as the cell, and
		// `new ForEach(colors, ...)` hands that cell straight over.
		var source:Dynamic = Reflect.field(n, "itemsState");
		if (source == null) return [];
		if (Std.isOfType(source, aui.state.State)) source = (cast source : aui.state.State<Dynamic>).get();
		if (source == null) return [];

		// An `Array`, or anything iterable -- `rui.structures.ImmutableList` is
		// the other collection a view is allowed to read, and it answers
		// `iterator()` like any other.
		var items:Array<Dynamic> = [];
		if (Std.isOfType(source, Array)) {
			items = cast source;
		} else {
			var makeIterator:Dynamic = Reflect.field(source, "iterator");
			if (!Reflect.isFunction(makeIterator)) return [];
			var iter:Dynamic = Reflect.callMethod(source, makeIterator, []);
			while (iter.hasNext()) items.push(iter.next());
		}

		var out:Array<View> = [];
		for (item in items) {
			var view:Dynamic = Reflect.callMethod(null, builder, [item]);
			if (view != null) out.push(cast view);
		}
		return out;
	}

	/** A `TabView`'s tabs, or null for anything else. **/
	static function tabsOf(n:View):Null<Array<aui.ui.Tab>> {
		if (n == null || n.viewType != "TabView") return null;
		var tabs:Dynamic = Reflect.field(n, "tabs");
		return tabs == null ? null : cast tabs;
	}

	/** A tab's title, for a consumer drawing the bar above the contents. **/
	public function tabTitle(n:View, index:Int):String {
		var tabs = tabsOf(n);
		if (tabs == null || index < 0 || index >= tabs.length) return "";
		return tabs[index].title;
	}

	public function tabIcon(n:View, index:Int):String {
		var tabs = tabsOf(n);
		if (tabs == null || index < 0 || index >= tabs.length) return "";
		return tabs[index].icon;
	}

	/**
		Which branch of a `ConditionalView` is live.

		Read through the state, so the answer is current at the moment it is
		asked rather than at the moment the tree was built.
	**/
	public function conditionValue(n:View):Bool {
		n = resolve(n);
		if (n == null) return false;
		var st:Dynamic = Reflect.field(n, "conditionState");
		return st == null ? false : st.get() == true;
	}

	/**
		A component is described by what it renders, never by itself.

		`ViewComponent` is a composition unit: it has no rendering of its own, so
		a consumer walking the tree would otherwise meet a node type no renderer
		knows. Resolving it here means every consumer of the pull contract sees
		the same thing -- the views the component is made of.
	**/
	static function resolve(n:View):View {
		var current = n;
		while (Std.isOfType(current, aui.ViewComponent)) {
			var comp:aui.ViewComponent = cast current;
			var inner = comp.expand();
			if (inner == null || inner == current) return current;
			current = inner;
		}
		return current;
	}

	/**
		The node to read a *value* from: a component expanded, then its thunk.

		Public and static because the bridge needs exactly this, and two helpers
		answering almost the same question is how they drift -- the bridge's copy
		did not expand components, so a component's text read back empty.
	**/
	public static function resolveValue(n:View):View {
		if (n == null) return null;
		n = resolve(n);
		if (n == null) return null;
		return n.liveBuild != null ? cast n.liveBuild() : n;
	}

	static function valueOf(n:View):View {
		return resolveValue(n);
	}

	public function hasProp(n:View, key:String):Bool {
		n = valueOf(n);
		if (n == null || n.properties == null) return false;
		return n.properties.exists(key);
	}

	public function stringProp(n:View, key:String):String {
		n = valueOf(n);
		if (n == null || n.properties == null) return "";
		var val:Dynamic = n.properties.get(key);
		return val != null ? Std.string(val) : "";
	}

	public function intProp(n:View, key:String):Int {
		n = valueOf(n);
		if (n == null || n.properties == null) return 0;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Int) : 0;
	}

	public function floatProp(n:View, key:String):Float {
		n = valueOf(n);
		if (n == null || n.properties == null) return 0.0;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Float) : 0.0;
	}

	public function boolProp(n:View, key:String):Bool {
		n = valueOf(n);
		if (n == null || n.properties == null) return false;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Bool) : false;
	}

	public function modifierCount(n:View):Int {
		n = resolve(n);
		if (n == null || n.modifierChain == null) return 0;
		return n.modifierChain.length;
	}

	public function modifierType(n:View, index:Int):String {
		n = resolve(n);
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return "";
		return Type.enumConstructor(n.modifierChain[index]);
	}

	public function modifierFloat(n:View, index:Int, param:Int):Float {
		n = resolve(n);
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return 0.0;
		var params = Type.enumParameters(n.modifierChain[index]);
		if (param < 0 || param >= params.length) return 0.0;
		var val:Dynamic = params[param];
		if (Std.isOfType(val, Float)) return val;
		if (Std.isOfType(val, Int)) return cast(val, Int) * 1.0;
		return 0.0;
	}

	public function modifierString(n:View, index:Int, param:Int):String {
		n = resolve(n);
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return "";
		var params = Type.enumParameters(n.modifierChain[index]);
		if (param < 0 || param >= params.length) return "";
		return Std.string(params[param]);
	}

	/**
		An index into a registry, never a closure: a handler handed to a foreign
		consumer would be untraceable. `-1` means the node has no action.
	**/
	/**
		Whether a modifier parameter is actually there.

		**Not in the pull contract, and that is the finding.** `modifierFloat`
		answers `0.0` both for "absent" and for "explicitly zero", and aui needs
		the difference: `Padding()` means the default 16dp — that is what
		`ComposeGenerator` emits — while `Padding(0)` means none. Encoding it in
		a sentinel value (NaN, -1) would make every consumer guess; the contract
		should grow an optional-parameter answer instead. Recorded in
		`atelier/nui-adoption.md`.
	**/
	public function modifierHasParam(n:View, index:Int, param:Int):Bool {
		n = resolve(n);
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return false;
		var params = Type.enumParameters(n.modifierChain[index]);
		if (param < 0 || param >= params.length) return false;
		return params[param] != null;
	}

	public function actionId(n:View):Int {
		n = resolve(n);
		if (actionOf(n) == null) return -1;
		var i = _actions.indexOf(n);
		if (i >= 0) return i;
		_actions.push(n);
		return _actions.length - 1;
	}

	/** Run an action by the identifier `actionId` handed out. **/
	public function invokeActionId(id:Int):Void {
		if (id < 0 || id >= _actions.length) return;
		invokeAction(_actions[id]);
	}

	static function actionOf(n:View):Null<StateAction> {
		if (n == null) return null;
		var a:Dynamic = Reflect.field(n, "stateAction");
		return a == null ? null : cast a;
	}

	/**
		Run the node's action.

		**aui's actions are not closures.** A `Button` carries a declarative
		`StateAction` — `Increment(count)`, `Toggle(flag)` — which
		`ComposeGenerator` translates to Kotlin at compile time. That translation
		does not exist at runtime, so a dynamic renderer has to *apply* the enum
		instead, which is what this does.

		Copying `sui`'s version here would have read a field named `action` that
		aui has never had: `Reflect.field` returns null, and every button would
		have done nothing at all, silently. The two backends look alike right up
		to the point where they do not.
	**/
	public function invokeAction(n:View):Void {
		n = resolve(n);
		apply(actionOf(n));
	}

	static function apply(action:Null<StateAction>):Void {
		if (action == null) return;

		switch (action) {
			case Increment(state, amount):
				var st:Dynamic = state;
				st.set(st.get() + (amount == null ? 1 : amount));

			case Decrement(state, amount):
				var st:Dynamic = state;
				st.set(st.get() - (amount == null ? 1 : amount));

			case SetValue(state, value):
				var st:Dynamic = state;
				st.set(value);

			case Toggle(state):
				var st:Dynamic = state;
				st.set(!st.get());

			case Append(state, value):
				var st:Dynamic = state;
				st.set(st.get() + value);

			// The curve describes *how* the change is shown, which is the
			// renderer's business, not the state's. The write is the same.
			case Animated(inner, _):
				apply(inner);
		}
	}
}
