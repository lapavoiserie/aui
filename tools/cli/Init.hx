package tools.cli;

import sys.FileSystem;
import sys.io.File;

class Init {
	public static function run(args:Array<String>, cwd:String):Void {
		if (args.length == 0) {
			Sys.println("Usage: aui init <project-name>");
			return;
		}

		var projectName = args[0];
		var projectDir = cwd + "/" + projectName;

		if (FileSystem.exists(projectDir)) {
			Sys.println("Error: Directory \"" + projectName + "\" already exists");
			return;
		}

		Sys.println("Creating new AUI project: " + projectName);

		Sys.command("mkdir -p " + shellEsc(projectDir + "/src"));

		var packageName = "com.aui." + projectName.toLowerCase();

		// aui.json
		var config = "{\n" + '  "appName": "' + projectName + '",\n' + '  "packageName": "' + packageName + '",\n'
			+ '  "minSdk": 24,\n' + '  "targetSdk": 35,\n' + '  "compileSdk": 35\n' + "}\n";
		File.saveContent(projectDir + "/aui.json", config);

		// build.hxml
		var buildHxml = [
			"-cp src", "-lib aui", "-D jvm", "--jvm build/app-logic.jar", "--macro aui.macros.ComposeGenerator.register()",
			"--main " + projectName, ""
		].join("\n");
		File.saveContent(projectDir + "/build.hxml", buildHxml);

		// Main app file
		var mainHx = [
			"import aui.App;",
			"import aui.View;",
			"import aui.ui.Text;",
			"import aui.ui.VStack;",
			"import aui.ui.Spacer;",
			"import aui.modifiers.ViewModifier;",
			"",
			"class " + projectName + " extends App {",
			"    public function new() {",
			"        super();",
			'        appName = "' + projectName + '";',
			'        packageName = "' + packageName + '";',
			"    }",
			"",
			"    public static function main() {",
			"        new " + projectName + "();",
			"    }",
			"",
			"    override public function body():View {",
			"        return new VStack([",
			'            new Text("Hello from AUI!").font(FontStyle.HeadlineLarge),',
			"            new Spacer(),",
			'            new Text("Built with Haxe + Jetpack Compose").foregroundColor(ColorValue.Gray)',
			"        ]);",
			"    }",
			"}",
			""
		].join("\n");
		File.saveContent(projectDir + "/src/" + projectName + ".hx", mainHx);

		// .gitignore
		File.saveContent(projectDir + "/.gitignore", [
			"build/", "android/.gradle/", "android/app/build/", "android/build/", "*.class", "*.jar", ".idea/", "*.iml",
			"android/local.properties", "android/gradlew", "android/gradlew.bat", "android/gradle/wrapper/gradle-wrapper.jar",
			""
		].join("\n"));

		Sys.println("");
		Sys.println("Project \"" + projectName + "\" created!");
		Sys.println("");
		Sys.println("Next steps:");
		Sys.println("  cd " + projectName);
		Sys.println("  aui build");
		Sys.println("  aui run");
	}

	static function shellEsc(s:String):String {
		return "'" + StringTools.replace(s, "'", "'\\''") + "'";
	}
}
