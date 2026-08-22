package aui.glance;

/**
	Extern binding to the Kotlin `aui.glance.GlanceHost` runtime object.

	The implementation lives in `aui/runtime/GlanceHost.kt`, which the
	ComposeGenerator copies into the generated Android project for an
	application that declares a `Glance` surface — the same arrangement as
	`aui.state.StateBridge`, and for the same reason: at runtime the JVM class
	loader pairs the Haxe jar with the Kotlin classes, both being in one APK.

	Do NOT instantiate or implement this on the Haxe side. It is a type
	signature, and the object it names is registered with a pusher by the
	generated code in the application's own package.
**/
@:keep
@:native("aui.glance.GlanceHost")
extern class GlanceHost {
	/** Take a new sample and hand it to every placed widget. **/
	public static function requestUpdate():Void;
}
