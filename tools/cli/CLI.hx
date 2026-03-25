package tools.cli;

class CLI {
	static var VERSION = "0.1.0";

	static function main() {
		var args = Sys.args();
		var cwd = determineCwd(args);

		if (args.length == 0) {
			printUsage();
			return;
		}

		var command = args[0];
		var commandArgs = args.slice(1);

		switch (command) {
			case "init":
				Init.run(commandArgs, cwd);
			case "build":
				Build.run(commandArgs, cwd);
			case "run":
				Build.run(commandArgs.concat(["--run"]), cwd);
			case "clean":
				Clean.run(cwd);
			case "version":
				Sys.println("aui " + VERSION);
			case "help":
				printUsage();
			default:
				Sys.println("Unknown command: " + command);
				printUsage();
		}
	}

	static function determineCwd(args:Array<String>):String {
		// When run via haxelib, the last arg is the working directory
		if (args.length > 0) {
			var lastArg = args[args.length - 1];
			if (sys.FileSystem.exists(lastArg) && sys.FileSystem.isDirectory(lastArg)) {
				args.pop();
				return lastArg;
			}
		}
		return Sys.getCwd();
	}

	static function printUsage():Void {
		Sys.println("AUI - Create native Android apps in Haxe (v" + VERSION + ")");
		Sys.println("");
		Sys.println("Usage: aui <command> [options]");
		Sys.println("");
		Sys.println("Commands:");
		Sys.println("  init <name>     Create a new AUI project");
		Sys.println("  build           Build the Android app");
		Sys.println("  run             Build and run on device/emulator");
		Sys.println("  clean           Remove build artifacts");
		Sys.println("  version         Show version");
		Sys.println("  help            Show this help");
		Sys.println("");
		Sys.println("Build options:");
		Sys.println("  --release       Build in release mode");
		Sys.println("  --verbose       Show detailed output");
	}
}
