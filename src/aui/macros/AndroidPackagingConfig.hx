package aui.macros;

/**
	Optional Android packaging configuration loaded from `aui.json#android`.

	When present, AUI applies these settings to the generated AndroidManifest,
	`build.gradle.kts`, and copies declared native libraries and asset directories
	into the Android project on every build.

	When absent (the entire `android` key missing), AUI behaves identically to
	upstream: no manifest extras, no ABI filters, no jniLibs/assets sync.

	All fields are optional so partial configurations work — e.g. setting only
	`abiFilters` without declaring jniLibs.

	**Schema example:**
	```json
	{
	  "appName": "...",
	  "packageName": "...",
	  "android": {
	    "extractNativeLibs": true,
	    "abiFilters": ["arm64-v8a"],
	    "useLegacyPackaging": true,
	    "jniLibs": {
	      "arm64-v8a": {
	        "libfoo.so": "/abs/path/to/source-binary"
	      }
	    },
	    "assets": {
	      "data": "/abs/path/to/source-dir"
	    }
	  }
	}
	```

	`jniLibs` is keyed by ABI subdirectory; the inner map is `destFilename → absoluteSourcePath`.
	The destination filename MUST match the Android packager pattern `lib*.so` or it will be
	dropped from the APK at packaging time.

	`assets` is `destSubdirectory → absoluteSourceDirectory`. The full source tree is
	mirrored into `android/app/src/main/assets/<destSubdirectory>/`.
**/
typedef AndroidPackagingConfig = {
	@:optional var extractNativeLibs:Bool;
	@:optional var abiFilters:Array<String>;
	@:optional var useLegacyPackaging:Bool;
	@:optional var jniLibs:Dynamic;
	@:optional var assets:Dynamic;
};
