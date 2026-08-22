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

	/**
		Release everything this application owns.

		Called from the generated Kotlin when the Activity is really going
		away — **not** on a rotation. That distinction is the point: Android
		destroys and recreates an Activity for a configuration change, and an
		application that took that for death rebuilt itself on every rotation,
		losing its state and leaving the previous instance's effects running.
		The generated host now retains the app across configuration changes
		and calls this only when the retention itself is cleared.

		Override to add your own teardown, and call `super.release()`.
	**/
	public function release():Void {
		lifetime.release();
	}

	public static function main() {}
}
