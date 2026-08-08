package aui.nui;

import nui.NodeSource;
import aui.View;

/**
	Describes a `aui` view tree through
	[nui's pull contract](https://lapavoiserie.github.io/nui/#/pull-mode).

	The node handle is `aui.View` itself: aui builds a live Haxe tree on the JVM,
	so nothing needs copying — the same choice `sui` and `cui` made.

	## What it is for, and what is still missing

	aui renders through generated Kotlin, so it does not need this to draw. It
	exists because `runtime/DynamicComposable.kt` — the Compose-side runtime
	renderer for hot reload — has **no Haxe half at all**, and is marked dead
	code in its own header for exactly that reason. This is that half, written
	against the shared contract instead of against a second private accessor
	set, which is what `sui` ended up with.

	**Not yet wired**, and saying so is the point: `DynamicComposable.kt` still
	declares its accessors as `external fun` over `System.loadLibrary`, which
	assumes a native library — but aui compiles Haxe to the **JVM**, where
	`StateBridge` already shows the right shape: Kotlin and Haxe on one JVM,
	resolved by the class loader, no JNI. Converting it, emitting it from
	`ComposeGenerator` and switching `MainActivity` to it needs an Android
	build to verify, so it is not claimed here.
**/
class ViewSource implements NodeSource<View> {
	final _root:View;

	public function new(root:View) {
		_root = root;
	}

	public function root():View
		return _root;

	/**
		The tree is rebuilt by re-running the app's `body()`; the caller replaces
		the root, so a source describes one generation of the tree.
	**/
	public function rebuild():Void {}

	public function typeOf(n:View):String {
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

	public function childCount(n:View):Int {
		if (n == null || n.children == null) return 0;
		return n.children.length;
	}

	public function childAt(n:View, index:Int):View {
		if (n == null || n.children == null || index < 0 || index >= n.children.length) return null;
		return n.children[index];
	}

	public function hasProp(n:View, key:String):Bool {
		if (n == null || n.properties == null) return false;
		return n.properties.exists(key);
	}

	public function stringProp(n:View, key:String):String {
		if (n == null || n.properties == null) return "";
		var val:Dynamic = n.properties.get(key);
		return val != null ? Std.string(val) : "";
	}

	public function intProp(n:View, key:String):Int {
		if (n == null || n.properties == null) return 0;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Int) : 0;
	}

	public function floatProp(n:View, key:String):Float {
		if (n == null || n.properties == null) return 0.0;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Float) : 0.0;
	}

	public function boolProp(n:View, key:String):Bool {
		if (n == null || n.properties == null) return false;
		var val:Dynamic = n.properties.get(key);
		return val != null ? cast(val, Bool) : false;
	}

	public function modifierCount(n:View):Int {
		if (n == null || n.modifierChain == null) return 0;
		return n.modifierChain.length;
	}

	public function modifierType(n:View, index:Int):String {
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return "";
		return Type.enumConstructor(n.modifierChain[index]);
	}

	public function modifierFloat(n:View, index:Int, param:Int):Float {
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return 0.0;
		var params = Type.enumParameters(n.modifierChain[index]);
		if (param < 0 || param >= params.length) return 0.0;
		var val:Dynamic = params[param];
		if (Std.isOfType(val, Float)) return val;
		if (Std.isOfType(val, Int)) return cast(val, Int) * 1.0;
		return 0.0;
	}

	public function modifierString(n:View, index:Int, param:Int):String {
		if (n == null || n.modifierChain == null || index < 0 || index >= n.modifierChain.length) return "";
		var params = Type.enumParameters(n.modifierChain[index]);
		if (param < 0 || param >= params.length) return "";
		return Std.string(params[param]);
	}

	public function actionId(n:View):Int {
		if (n == null) return -1;
		var id:Dynamic = Reflect.field(n, "actionId");
		return id != null ? cast(id, Int) : -1;
	}

	/**
		Run the node's action.

		Called directly rather than through an id: on the JVM the tree and the
		closure are ordinary objects the garbage collector can see, so the
		indirection `sui` needs — where an ARC-captured closure is invisible to
		the hxcpp GC — has no reason to exist here.
	**/
	public function invokeAction(n:View):Void {
		if (n == null) return;
		var action:Dynamic = Reflect.field(n, "action");
		if (action != null) action();
	}
}
