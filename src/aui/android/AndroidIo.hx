package aui.android;

/**
	Extern binding to the Kotlin `aui.android.AndroidIo` runtime helpers.

	Implementation lives in `aui/runtime/AndroidIo.kt`, copied into every
	generated AUI Android project by the ComposeGenerator. Provides two
	idempotent operations that the Haxe `sys.*` API doesn't cover:

	- `copyAssetDir` mirrors a directory in the APK's `AssetManager` to a
	  filesystem path under e.g. `Context.getFilesDir()`. Returns the number
	  of files actually copied (skips ones that already exist).
	- `symlink` creates a POSIX symbolic link at `linkpath` pointing to
	  `target` (uses `android.system.Os.symlink`, API 21+). EEXIST is silently
	  ignored, so calling it on every app launch is safe.
**/
@:keep
@:native("aui.android.AndroidIo")
extern class AndroidIo {
	public static function copyAssetDir(assets:Dynamic, src:String, destDir:String):Int;
	public static function symlink(target:String, linkpath:String):Void;
}
