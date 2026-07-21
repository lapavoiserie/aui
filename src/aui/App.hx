package aui;

import aui.View;

@:autoBuild(aui.macros.StateMacro.build())
class App {
	public var appName:String = "HaxeApp";
	public var bundleIdentifier:String = "com.haxe.app";
	public var packageName:String = "com.haxe.app";
	public var minSdk:Int = 24;
	public var targetSdk:Int = 35;
	public var compileSdk:Int = 35;

	public function new() {}

	public function body():View {
		return new View();
	}

	/**
		Lifecycle hook invoked from the generated `MainActivity.kt` after
		`super.onCreate(...)` and before `setContent { ... }`.

		Default implementation is empty. Override in your App subclass to perform
		one-shot setup that needs the Android Context — typically extracting
		assets, creating symlinks under `filesDir`, or initializing JNI bridges.

		@param nativeLibraryDir absolute path to the APK's extracted lib/<abi>/ dir.
		@param filesDir absolute path to the app's private internal storage (`Context.getFilesDir()`).
		@param assets the Android `AssetManager` (passed as `Dynamic` so this Haxe API
		              stays free of Android type imports).
	**/
	public function onAndroidContextReady(nativeLibraryDir:String, filesDir:String, assets:Dynamic):Void {}

	public static function main() {}
}
