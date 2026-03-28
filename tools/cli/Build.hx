package tools.cli;

import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class Build {
	static var verbose:Bool = false;
	static var release:Bool = false;
	static var runAfterBuild:Bool = false;
	static var cwd:String = "";

	public static function run(args:Array<String>, workDir:String):Void {
		cwd = workDir;
		for (arg in args) {
			switch (arg) {
				case "--verbose": verbose = true;
				case "--release": release = true;
				case "--run": runAfterBuild = true;
			}
		}

		var config = loadConfig();
		log("Building AUI project: " + config.appName);

		log("\n[1/3] Compiling Haxe...");
		if (!runHaxe()) {
			Sys.println("Error: Haxe compilation failed");
			Sys.exit(1);
		}

		log("[2/3] Preparing Android project...");
		ensureGradleWrapper();

		log("[3/3] Building Android APK...");
		if (!runGradle()) {
			Sys.println("Error: Gradle build failed");
			Sys.exit(1);
		}

		var buildType = release ? "release" : "debug";
		var apkPath = cwd + "/android/app/build/outputs/apk/" + buildType + "/app-" + buildType + ".apk";
		Sys.println("\nBuild successful!");
		Sys.println("APK: " + apkPath);

		if (runAfterBuild) installAndRun(config, apkPath);
	}

	static function loadConfig():ProjectConfig {
		var configPath = cwd + "/aui.json";
		if (FileSystem.exists(configPath)) {
			try {
				var json = haxe.Json.parse(File.getContent(configPath));
				return {
					appName: json.appName != null ? json.appName : "HaxeApp",
					packageName: json.packageName != null ? json.packageName : "com.haxe.app"
				};
			} catch (e:Dynamic) {}
		}
		return {appName: "HaxeApp", packageName: "com.haxe.app"};
	}

	static function runHaxe():Bool {
		if (!FileSystem.exists(cwd + "/build.hxml")) {
			Sys.println("Error: build.hxml not found");
			return false;
		}
		return shell("cd " + shellEscape(cwd) + " && haxe build.hxml") == 0;
	}

	static function ensureGradleWrapper():Void {
		var androidDir = cwd + "/android";
		var gradlewJar = androidDir + "/gradle/wrapper/gradle-wrapper.jar";

		if (!FileSystem.exists(gradlewJar)) {
			log("  Bootstrapping Gradle wrapper...");
			var gradleBin = findCachedGradle();
			if (gradleBin != null) {
				shell("cd " + shellEscape(androidDir) + " && " + shellEscape(gradleBin) + " wrapper --gradle-version 8.11.1");
			} else {
				if (shell("cd " + shellEscape(androidDir) + " && gradle wrapper --gradle-version 8.11.1") != 0) {
					Sys.println("Warning: Could not bootstrap Gradle wrapper.");
				}
			}
		}
	}

	static function findCachedGradle():Null<String> {
		var home = Sys.getEnv("HOME");
		if (home == null) return null;
		var wrapperDir = home + "/.gradle/wrapper/dists";
		if (!FileSystem.exists(wrapperDir)) return null;
		try {
			for (entry in FileSystem.readDirectory(wrapperDir)) {
				if (StringTools.startsWith(entry, "gradle-8.")) {
					var distDir = wrapperDir + "/" + entry;
					for (sub in FileSystem.readDirectory(distDir)) {
						var innerDir = distDir + "/" + sub;
						if (FileSystem.isDirectory(innerDir)) {
							for (gradleDir in FileSystem.readDirectory(innerDir)) {
								var binPath = innerDir + "/" + gradleDir + "/bin/gradle";
								if (FileSystem.exists(binPath)) return binPath;
							}
						}
					}
				}
			}
		} catch (e:Dynamic) {}
		return null;
	}

	static function runGradle():Bool {
		var androidDir = cwd + "/android";
		var task = release ? "assembleRelease" : "assembleDebug";
		shell("chmod +x " + shellEscape(androidDir + "/gradlew"));
		return shell("cd " + shellEscape(androidDir) + " && ./gradlew " + task) == 0;
	}

	static function installAndRun(config:ProjectConfig, apkPath:String):Void {
		log("\nInstalling and running...");
		var adb = findAdb();
		if (shell(shellEscape(adb) + " install -r " + shellEscape(apkPath)) != 0) {
			Sys.println("Error: Install failed. Is a device/emulator connected?");
			return;
		}
		var activity = config.packageName + "/" + config.packageName + ".MainActivity";
		shell(shellEscape(adb) + " shell am start -n " + activity);
		Sys.println("App launched!");
	}

	static function findAdb():String {
		var home = Sys.getEnv("HOME");
		if (home != null) {
			var adb = home + "/Library/Android/sdk/platform-tools/adb";
			if (FileSystem.exists(adb)) return adb;
		}
		var androidHome = Sys.getEnv("ANDROID_HOME");
		if (androidHome != null && androidHome != "") {
			var adb = androidHome + "/platform-tools/adb";
			if (FileSystem.exists(adb)) return adb;
		}
		return "adb";
	}

	static function shell(cmd:String):Int {
		if (verbose) Sys.println("  > " + cmd);
		var exitCode = Sys.command("/bin/sh", ["-c", cmd]);
		return exitCode;
	}

	static function shellEscape(s:String):String {
		return "'" + StringTools.replace(s, "'", "'\\''") + "'";
	}

	static function log(msg:String):Void {
		Sys.println(msg);
	}
}

typedef ProjectConfig = {
	appName:String,
	packageName:String
};
