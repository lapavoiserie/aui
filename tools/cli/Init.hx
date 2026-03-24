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
			Sys.println('Error: Directory "${projectName}" already exists');
			return;
		}

		Sys.println('Creating new AUI project: ${projectName}');

		// Create project structure
		FileSystem.createDirectory(projectDir);
		FileSystem.createDirectory(projectDir + "/src");

		// Generate aui.json
		var packageName = "com.aui." + projectName.toLowerCase();
		var config = haxe.Json.stringify({
			appName: projectName,
			packageName: packageName,
			minSdk: 24,
			targetSdk: 35,
			compileSdk: 35
		}, "  ");
		File.saveContent(projectDir + "/aui.json", config);

		// Generate build.hxml
		var buildHxml = '-cp src
-lib aui
-D jvm
--jvm build/app-logic.jar
--macro aui.macros.ComposeGenerator.register()
--main ${projectName}
';
		File.saveContent(projectDir + "/build.hxml", buildHxml);

		// Generate main app file
		var mainHx = 'import aui.App;
import aui.View;
import aui.ui.Text;
import aui.ui.VStack;
import aui.ui.Spacer;
import aui.modifiers.ViewModifier;

class ${projectName} extends App {
    public function new() {
        super();
        appName = "${projectName}";
        packageName = "${packageName}";
    }

    override public function body():View {
        return new VStack([
            new Text("Hello from AUI!").font(FontStyle.HeadlineLarge),
            new Spacer(),
            new Text("Built with Haxe + Jetpack Compose").foregroundColor(ColorValue.Gray)
        ]);
    }
}
';
		File.saveContent(projectDir + '/src/${projectName}.hx', mainHx);

		// Generate .gitignore
		File.saveContent(projectDir + "/.gitignore", 'build/
android/.gradle/
android/app/build/
android/build/
*.class
*.jar
.idea/
*.iml
local.properties
');

		Sys.println('
Project "${projectName}" created successfully!

Next steps:
  cd ${projectName}
  aui build
  aui run
');
	}
}
