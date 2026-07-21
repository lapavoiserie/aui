package aui.state;

/**
	Extern binding to the Kotlin `aui.state.StateBridge` runtime object.

	The implementation lives in `aui/runtime/StateBridge.kt`, which AUI's
	ComposeGenerator copies into the generated Android project on every build.
	At runtime the JVM/Kotlin singleton is resolved by the standard JVM class
	loader — both the Haxe `app-logic.jar` and the Kotlin-compiled
	StateBridge.class are in the same APK classpath.

	Do NOT instantiate or implement this class on the Haxe side. It is purely a
	type signature for the macro's emitted `aui.state.StateBridge.create(...)`
	calls and for `aui.state.State` to invoke at runtime.
**/
@:keep
@:native("aui.state.StateBridge")
extern class StateBridge {
	public static function create(initialValue:Dynamic):Dynamic;
	public static function read(state:Dynamic):Dynamic;
	public static function write(state:Dynamic, value:Dynamic):Void;
}
