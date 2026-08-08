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
	tree stays reachable from `_root` here, so the garbage collector can see
	every node Kotlin is holding.
**/
@:keep
class ViewNodeBridge {
	static var _app:Dynamic = null;
	static var _root:View = null;
	static var _source:ViewSource = null;

	/** Set the app instance and build the first tree. **/
	public static function setApp(app:Dynamic):Void {
		_app = app;
		rebuild();
	}

	/** Re-evaluate the tree by re-running the app's `body()`. **/
	public static function rebuild():Void {
		if (_app == null) return;
		_root = _app.body();
		_source = new ViewSource(_root);
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
	// All forward to the ViewSource. Kotlin may ask before setApp() has run, so
	// a reader always exists: its accessors already answer "" / 0 / false for a
	// null node.

	static function reader():ViewSource {
		if (_source == null) _source = new ViewSource(null);
		return _source;
	}

	public static function getRoot():Dynamic {
		return _root;
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

	public static function getText(node:Dynamic):String {
		if (node == null) return "";
		var content:Dynamic = Reflect.field(node, "content");
		return content != null ? Std.string(content) : "";
	}

	public static function getButtonLabel(node:Dynamic):String {
		if (node == null) return "";
		var label:Dynamic = Reflect.field(node, "label");
		return label != null ? Std.string(label) : "";
	}
}
