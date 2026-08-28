package aui.runtime;

import aui.View;
import aui.nui.ViewSource;

/**
	The entry points Kotlin calls to read a live Haxe view tree.

	## Why it is plain static methods on the JVM

	`aui.state.StateBridge` is the same bridge in the other direction — Haxe
	calling Kotlin — and it needs no JNI at all: both halves are on one JVM and
	the class loader resolves them, since `app-logic.jar` and the Kotlin classes
	sit in the same APK classpath. This is that pattern, mirrored.

	The previous attempt at a dynamic renderer got this wrong: `DynamicComposable.kt`
	declared its accessors `external fun` over `System.loadLibrary("haxebridge")`,
	which is how **sui** must do it — sui compiles Haxe to C++, so its bridge
	really is native. aui compiles to the JVM. Copying the shape of a sibling
	backend across a difference that mattered is what left that file dead.

	## Why the walk is not here

	It is in `aui.nui.ViewSource`, aui's implementation of
	[nui's pull contract](https://lapavoiserie.github.io/nui/#/pull-mode), and
	these methods forward to it. `sui` learned this the expensive way: it kept a
	private accessor set beside the contract, and the two were free to drift
	while answering slightly different questions — which does not crash, it
	renders something slightly wrong.

	These static entry points exist only because Kotlin calls them by name and
	an interface has no static methods.

	## Handles

	A node crosses as `Dynamic` — `java.lang.Object` on the JVM — so Kotlin holds
	it as `Any` and hands it back without knowing anything about `aui.View`. The
	tree stays reachable from the Primary `ViewRoot` here, so the garbage
	collector can see every node Kotlin is holding.

	## One bridge, N roots

	The per-root state — the app, its last tree, its source — lives in
	`ViewRoot`; these statics route to the Primary one. The node accessors
	below take the node they are asked about and the source's caches are keyed
	by node, so they are root-agnostic: a second root shares them unchanged
	and only needs its own `ViewRoot` for "rebuild" and "which root".
**/
@:keep
class ViewNodeBridge {
	static var _primary:Null<ViewRoot> = null;

	// Kotlin may ask before setApp() has run; a reader must exist even with
	// no root at all. Its accessors answer "" / 0 / false for a null node.
	static var _orphan:Null<ViewSource> = null;

	/** Set the app instance and build the first tree. **/
	public static function setApp(app:Dynamic):Void {
		_primary = new ViewRoot(app);
		_primary.rebuild();
		// The instance is whole here, so this is where the Glance surface
		// starts following its own state. Not in `mui.App`'s constructor: the
		// subclass has not initialised its @:state fields yet there.
		//
		// Guarded because `aui` is a backend on its own as well as mui's:
		// naming `aui.mui` unconditionally made every plain aui application
		// require the whole mui chain to compile, which is not a dependency
		// this library gets to impose. `mui_backend` is the flag, not `mui` --
		// the latter is false when mui arrives through a `-cp`.
		#if mui_backend
		var mine = Std.downcast(app, aui.mui.App);
		if (mine != null) aui.mui.GlanceBridge.follow(mine);
		#end
	}

	/**
		Drop the Primary root and release its application.

		Called from the generated Kotlin when the retained app is cleared —
		the Activity is finishing, not rotating. Without it the app, its
		effects and its whole tree stayed reachable from this static for as
		long as the process lived, and a second `setApp` merely orphaned the
		first: the rotation bug's real cost.

		Idempotent, and safe to call before any accessor: the readers already
		answer "" / 0 / false with no root, the same shrug they give before
		the first `setApp`.
	**/
	public static function releaseApp():Void {
		var root = _primary;
		_primary = null;
		// Before anything else: an effect still holding the old application is
		// exactly the shape of the rotation bug this method exists to fix.
		#if mui_backend
		aui.mui.GlanceBridge.unfollow();
		#end
		if (root == null) return;
		// Typed, not `root.app.release()`: the record holds the app as
		// `Dynamic`, and a dynamic call is a reflective one that dead-code
		// elimination cannot see — `release()` would compile away under
		// `-dce full` and fail at the one moment it is needed.
		var app = Std.downcast(root.app, aui.App);
		if (app != null) app.release();
	}

	/** The Primary root's record, or null before setApp(). A future host
		driving a second surface holds its own `ViewRoot` instead. **/
	public static function primary():Null<ViewRoot> {
		return _primary;
	}

	static var _pumpBroken = false;

	/** Let Haxe's scheduled work run — called from the host's 100ms beat.
		A `haxe.Timer` on the JVM registers with the current thread's event
		loop, and Android's UI thread has a Looper, not a Haxe loop: without
		this an application's timer never fires, silently. Kotlin calls it;
		nothing in Haxe does. **/
	public static function pumpHaxeEvents():Void {
		if (_pumpBroken) return;
		try {
			#if (target.threaded && !cppia)
			sys.thread.Thread.current().events.progress();
			#end
		} catch (e:Dynamic) {
			_pumpBroken = true;
			trace("[aui] no Haxe event loop on this thread; haxe.Timer will not fire: " + e);
		}
	}

	/** Re-evaluate the Primary tree by re-running the app's `body()`. **/
	public static function rebuild():Void {
		if (_primary != null) _primary.rebuild();
	}

	/**
		aui's view of itself through the shared node model.

		Exposed so a consumer that knows nothing about aui — a devtool, an
		inspector, another renderer — can walk the tree through `nui`.
	**/
	public static function source():ViewSource {
		return reader();
	}

	// --- Accessors called from Kotlin -------------------------------------
	//
	// All forward to a ViewSource. They take the node they are asked about,
	// so they serve any root's nodes; the Primary's source is preferred for
	// its caches and classify attribution.

	static function reader():ViewSource {
		if (_primary != null) return _primary.source;
		if (_orphan == null) _orphan = new ViewSource(null);
		return _orphan;
	}

	public static function getRoot():Dynamic {
		return _primary == null ? null : _primary.rootHandle();
	}

	public static function getType(node:Dynamic):String {
		return reader().typeOf(cast node);
	}

	public static function childCount(node:Dynamic):Int {
		return reader().childCount(cast node);
	}

	public static function getChild(node:Dynamic, index:Int):Dynamic {
		return reader().childAt(cast node, index);
	}

	public static function hasProperty(node:Dynamic, key:String):Bool {
		return reader().hasProp(cast node, key);
	}

	public static function getProperty(node:Dynamic, key:String):String {
		return reader().stringProp(cast node, key);
	}

	public static function getFloatProperty(node:Dynamic, key:String):Float {
		return reader().floatProp(cast node, key);
	}

	public static function getBoolProperty(node:Dynamic, key:String):Bool {
		return reader().boolProp(cast node, key);
	}

	public static function modifierCount(node:Dynamic):Int {
		return reader().modifierCount(cast node);
	}

	public static function modifierType(node:Dynamic, index:Int):String {
		return reader().modifierType(cast node, index);
	}

	public static function modifierFloat(node:Dynamic, index:Int, param:Int):Float {
		return reader().modifierFloat(cast node, index, param);
	}

	public static function modifierString(node:Dynamic, index:Int, param:Int):String {
		return reader().modifierString(cast node, index, param);
	}

	/**
		Whether a modifier parameter is present — see `ViewSource.modifierHasParam`.
		The pull contract cannot express an optional parameter yet.
	**/
	public static function modifierHasParam(node:Dynamic, index:Int, param:Int):Bool {
		return reader().modifierHasParam(cast node, index, param);
	}

	public static function actionId(node:Dynamic):Int {
		return reader().actionId(cast node);
	}

	/**
		Run a node's action.

		aui's actions are declarative `StateAction`s, applied by the source. The
		write lands in a `State<T>`, which is backed by a Compose `MutableState`
		through `aui.state.StateBridge` — so the recomposition is Compose's own,
		not something this bridge has to arrange.
	**/
	public static function invokeAction(node:Dynamic):Void {
		reader().invokeAction(cast node);
	}

	// --- Leaves outside the contract's property vocabulary -----------------
	//
	// `Text.content` and `Button.label` are fields on the concrete view, not
	// entries in `properties`, so the pull contract has no key for them. Read
	// here rather than pretended into the contract.

	/**
		The node to read a *value* from.

		When `LiveProps` deferred a view's values, the node itself carries neutral
		ones and `liveBuild` holds the real expression. Evaluating it here is the
		whole point: the state read then happens inside the composable asking for
		the value, so Compose recomposes that one rather than the whole tree.

		Only for values. Actions, children and bound states stay on the original
		node -- re-running the constructor would hand back a different closure.
	**/
	static function valueOf(node:Dynamic):Dynamic {
		if (node == null) return null;
		return ViewSource.resolveValue(cast node);
	}

	public static function getText(node:Dynamic):String {
		node = valueOf(node);
		if (node == null) return "";

		// A state template -- `Text.withState("compteur : {count}")` -- has no
		// content of its own: the static generator interpolates it into Kotlin.
		// There is no Kotlin here, so resolve the names against the state
		// registry instead. Without this a counter renders an empty string
		// forever, which reads as a renderer bug rather than a missing feature.
		var template:Dynamic = Reflect.field(node, "stateTemplate");
		if (template != null) return resolveTemplate(Std.string(template));

		var content:Dynamic = Reflect.field(node, "content");
		return content != null ? Std.string(content) : "";
	}

	/** Replace every `{name}` with the current value of that state. **/
	static function resolveTemplate(template:String):String {
		var out = new StringBuf();
		var i = 0;

		while (i < template.length) {
			var open = template.indexOf("{", i);
			if (open < 0) {
				out.add(template.substr(i));
				break;
			}
			var close = template.indexOf("}", open);
			if (close < 0) {
				out.add(template.substr(i));
				break;
			}

			out.add(template.substring(i, open));
			var name = template.substring(open + 1, close);
			var state:Dynamic = aui.state.State.getByName(name);
			// An unknown name is left as written rather than blanked: seeing
			// `{cont}` on screen says "this name is wrong", an empty string says
			// nothing at all.
			out.add(state == null ? "{" + name + "}" : Std.string(state.get()));
			i = close + 1;
		}

		return out.toString();
	}

	public static function getButtonLabel(node:Dynamic):String {
		node = valueOf(node);
		if (node == null) return "";
		var label:Dynamic = Reflect.field(node, "label");
		return label != null ? Std.string(label) : "";
	}

	/** A `Section`'s header, or "" when it has none. **/
	public static function sectionHeader(node:Dynamic):String {
		if (node == null) return "";
		var header:Dynamic = Reflect.field(node, "header");
		return header != null ? Std.string(header) : "";
	}

	public static function tabTitle(node:Dynamic, index:Int):String {
		return reader().tabTitle(cast node, index);
	}

	public static function tabIcon(node:Dynamic, index:Int):String {
		return reader().tabIcon(cast node, index);
	}

	public static function conditionValue(node:Dynamic):Bool {
		return reader().conditionValue(cast node);
	}

	public static function fieldPlaceholder(node:Dynamic):String {
		node = valueOf(node);
		if (node == null) return "";
		var p:Dynamic = Reflect.field(node, "placeholder");
		return p != null ? Std.string(p) : "";
	}

	// --- Writes, the one direction the pull contract does not describe -------
	//
	// A `TextField` and a `Toggle` are edited by the user, so the value has to
	// travel *back*. The contract is about reading a tree; this is the state
	// underneath it, and the write goes through `State.set` -- the same call an
	// action makes -- so nothing here bypasses the reactive core.

	public static function fieldText(node:Dynamic):String {
		var st = stateOf(node, "textState");
		return st == null ? "" : Std.string(st.get());
	}

	public static function setFieldText(node:Dynamic, value:String):Void {
		var st = stateOf(node, "textState");
		if (st != null) st.set(value);
	}

	public static function toggleLabel(node:Dynamic):String {
		node = valueOf(node);
		if (node == null) return "";
		var label:Dynamic = Reflect.field(node, "label");
		return label != null ? Std.string(label) : "";
	}

	public static function toggleValue(node:Dynamic):Bool {
		var st = stateOf(node, "isOnState");
		return st == null ? false : st.get() == true;
	}

	public static function setToggleValue(node:Dynamic, value:Bool):Void {
		var st = stateOf(node, "isOnState");
		if (st != null) st.set(value);
	}

	public static function sliderValue(node:Dynamic):Float {
		var st = stateOf(node, "valueState");
		if (st == null) return 0.0;
		var v:Dynamic = st.get();
		return v == null ? 0.0 : (v : Float);
	}

	public static function setSliderValue(node:Dynamic, value:Float):Void {
		var st = stateOf(node, "valueState");
		if (st != null) st.set(value);
	}

	public static function sliderMin(node:Dynamic):Float {
		return reader().floatProp(node, "min");
	}

	public static function sliderMax(node:Dynamic):Float {
		return reader().floatProp(node, "max");
	}

	/** A state a view holds under `field`, or null if it was built without one. **/
	static function stateOf(node:Dynamic, field:String):Null<Dynamic> {
		if (node == null) return null;
		var st:Dynamic = Reflect.field(node, field);
		return st;
	}
}
