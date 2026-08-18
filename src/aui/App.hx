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

	/**
		What this application owns for as long as it runs.

		An effect an application starts — watching connectivity, a subscription,
		a timer — has to be stopped, and there is exactly one moment every
		backend agrees on: the application is over.

		```haxe
		lifetime.own(new Effect(() -> { … Effect.onCleanup(stop); }).dispose);
		```

		**A view lifetime exists too**, through `lifetime.keep(key, start)`: it
		lasts as long as `body()` keeps declaring that key. Not as long as the
		view is on screen — those differ, and the difference is deliberate. See
		`rui.Lifetime.keep`.
	**/
	public final lifetime = new rui.Lifetime();

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
