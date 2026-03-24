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

	public function new() {}

	public function body():View {
		return new View();
	}

	public static function main() {}
}
