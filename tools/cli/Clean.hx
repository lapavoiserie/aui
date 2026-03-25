package tools.cli;

class Clean {
	public static function run(cwd:String):Void {
		Sys.println("Cleaning build artifacts...");
		removeDir(cwd + "/build");
		removeDir(cwd + "/android/app/build");
		removeDir(cwd + "/android/.gradle");
		removeDir(cwd + "/android/app/src/main/kotlin/com/aui/generated");
		Sys.println("Clean complete.");
	}

	static function removeDir(path:String):Void {
		if (sys.FileSystem.exists(path)) {
			Sys.command("rm -rf '" + StringTools.replace(path, "'", "'\\''") + "'");
			Sys.println("  Removed: " + path);
		}
	}
}
