package tools.cli;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class Build {
	static var verbose:Bool = false;
	static var release:Bool = false;
	static var runAfterBuild:Bool = false;
	static var device:Bool = false;

	public static function run(args:Array<String>, cwd:String):Void {
		for (arg in args) {
			switch (arg) {
				case "--verbose":
					verbose = true;
				case "--release":
					release = true;
				case "--run":
					runAfterBuild = true;
				case "--device":
					device = true;
			}
		}

		Sys.setCwd(cwd);

		var config = loadConfig(cwd);

		log("Building AUI project: " + config.appName);

		// Stage 1: Haxe compilation (JVM jar + Compose Kotlin via macros)
		log("\n[1/3] Compiling Haxe...");
		if (!runHaxe(cwd)) {
			Sys.println("Error: Haxe compilation failed");
			Sys.exit(1);
		}

		// Stage 2: Ensure Gradle wrapper exists
		log("[2/3] Preparing Android project...");
		ensureGradleWrapper(cwd);

		// Stage 3: Gradle build
		log("[3/3] Building Android APK...");
		if (!runGradle(cwd)) {
			Sys.println("Error: Gradle build failed");
			Sys.exit(1);
		}

		var buildType = release ? "release" : "debug";
		var apkPath = cwd + "/android/app/build/outputs/apk/" + buildType + "/app-" + buildType + ".apk";
		Sys.println("\nBuild successful!");
		Sys.println("APK: " + apkPath);

		if (runAfterBuild) {
			installAndRun(cwd, config, apkPath);
		}
	}

	static function loadConfig(cwd:String):ProjectConfig {
		var configPath = cwd + "/aui.json";
		if (FileSystem.exists(configPath)) {
			try {
				var content = File.getContent(configPath);
				var json = haxe.Json.parse(content);
				return {
					appName: json.appName != null ? json.appName : "HaxeApp",
					packageName: json.packageName != null ? json.packageName : "com.haxe.app",
					minSdk: json.minSdk != null ? json.minSdk : 24,
					targetSdk: json.targetSdk != null ? json.targetSdk : 35,
					compileSdk: json.compileSdk != null ? json.compileSdk : 35
				};
			} catch (e:Dynamic) {}
		}

		return {
			appName: "HaxeApp",
			packageName: "com.haxe.app",
			minSdk: 24,
			targetSdk: 35,
			compileSdk: 35
		};
	}

	static function runHaxe(cwd:String):Bool {
		if (!FileSystem.exists(cwd + "/build.hxml")) {
			Sys.println("Error: build.hxml not found");
			return false;
		}
		return runCommand("haxe", ["build.hxml"]) == 0;
	}

	static function ensureGradleWrapper(cwd:String):Void {
		var androidDir = cwd + "/android";
		var gradlewJar = androidDir + "/gradle/wrapper/gradle-wrapper.jar";

		if (!FileSystem.exists(gradlewJar)) {
			log("  Bootstrapping Gradle wrapper...");

			// Try to find a cached Gradle installation
			var home = Sys.getEnv("HOME");
			var gradleBin = findCachedGradle(home);

			if (gradleBin != null) {
				Sys.setCwd(androidDir);
				runCommand(gradleBin, ["wrapper", "--gradle-version", "8.11.1"]);
				Sys.setCwd(cwd);
			} else {
				// Check if gradle is in PATH
				var result = runCommand("gradle", ["wrapper", "--gradle-version", "8.11.1"]);
				if (result != 0) {
					Sys.println("Warning: Could not bootstrap Gradle wrapper.");
					Sys.println("Please install Gradle or run 'gradle wrapper' in android/");
				}
			}
		}
	}

	static function findCachedGradle(home:String):Null<String> {
		if (home == null) return null;

		// Look for cached Gradle 8.11.1
		var wrapperDir = home + "/.gradle/wrapper/dists";
		if (!FileSystem.exists(wrapperDir)) return null;

		try {
			for (entry in FileSystem.readDirectory(wrapperDir)) {
				if (StringTools.startsWith(entry, "gradle-8.11.1")) {
					var distDir = wrapperDir + "/" + entry;
					for (sub in FileSystem.readDirectory(distDir)) {
						var binPath = distDir + "/" + sub + "/gradle-8.11.1/bin/gradle";
						if (FileSystem.exists(binPath)) {
							return binPath;
						}
					}
				}
			}
		} catch (e:Dynamic) {}

		return null;
	}

	static function runGradle(cwd:String):Bool {
		var androidDir = cwd + "/android";
		var task = release ? "assembleRelease" : "assembleDebug";

		Sys.setCwd(androidDir);
		var result = runCommand("./gradlew", [task]);
		Sys.setCwd(cwd);

		return result == 0;
	}

	static function installAndRun(cwd:String, config:ProjectConfig, apkPath:String):Void {
		log("\nInstalling and running...");

		if (!FileSystem.exists(apkPath)) {
			Sys.println("Error: APK not found at " + apkPath);
			return;
		}

		if (runCommand("adb", ["install", "-r", apkPath]) != 0) {
			Sys.println("Error: Failed to install APK. Is a device/emulator connected?");
			return;
		}

		var activity = config.packageName + "/" + config.packageName + ".MainActivity";
		runCommand("adb", ["shell", "am", "start", "-n", activity]);

		Sys.println("App launched!");
	}

	static function runCommand(cmd:String, args:Array<String>):Int {
		if (verbose) {
			Sys.println("  > " + cmd + " " + args.join(" "));
		}

		try {
			var process = new Process(cmd, args);
			var exitCode = process.exitCode();

			if (verbose || exitCode != 0) {
				var stdout = process.stdout.readAll().toString();
				var stderr = process.stderr.readAll().toString();
				if (stdout.length > 0) Sys.println(stdout);
				if (stderr.length > 0) Sys.println(stderr);
			}

			process.close();
			return exitCode;
		} catch (e:Dynamic) {
			if (verbose) {
				Sys.println("Error running: " + cmd + " - " + Std.string(e));
			}
			return 1;
		}
	}

	static function log(msg:String):Void {
		Sys.println(msg);
	}
}

typedef ProjectConfig = {
	appName:String,
	packageName:String,
	minSdk:Int,
	targetSdk:Int,
	compileSdk:Int
};
