package tools.cli;

import sys.FileSystem;

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
		if (FileSystem.exists(path)) {
			deleteDirRecursive(path);
			Sys.println("  Removed: " + path);
		}
	}

	static function deleteDirRecursive(path:String):Void {
		if (FileSystem.isDirectory(path)) {
			for (entry in FileSystem.readDirectory(path)) {
				deleteDirRecursive(path + "/" + entry);
			}
			FileSystem.deleteDirectory(path);
		} else {
			FileSystem.deleteFile(path);
		}
	}
}
