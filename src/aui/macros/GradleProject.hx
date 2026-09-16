package aui.macros;

#if macro
import sys.FileSystem;
import sys.io.File;
import aui.macros.AndroidPackagingConfig;

using StringTools;

class GradleProject {
	public static function generate(config:{
		appName:String,
		packageName:String,
		minSdk:Int,
		targetSdk:Int,
		compileSdk:Int,
		?android:AndroidPackagingConfig,
		/** The application's own `<uses-permission>` entries, from
			`aui.json`. Separate from a capability's, which travel with the
			capability. **/
		?permissions:Array<String>,
		/** The application's own `<application>` children, from
			`aui.json`. Separate from a capability's, for the same reason its
			permissions are. **/
		?components:Array<String>,
		/** The application declares a `Glance` surface, so the project needs
			the App Widget: its Jetpack Glance dependency, its receiver in the
			manifest, and the provider XML the receiver points at. **/
		?glanceWidget:Bool
	}):Void {
		var androidDir = "android";
		var appDir = androidDir + "/app";
		var srcDir = appDir + "/src/main";

		// Create directories
		ensureDir(androidDir);
		ensureDir(appDir);
		ensureDir(srcDir);
		ensureDir(srcDir + "/kotlin");
		ensureDir(srcDir + "/res/values");

		generateRootBuildGradle(androidDir);
		generateSettings(androidDir, config.appName);
		generateAppBuildGradle(appDir, config);
		generateManifest(srcDir, config);
		generateGradleWrapper(androidDir);
		generateTheme(srcDir, config.appName);
		generateProguard(appDir);
		generateGradleProperties(androidDir);
		generateLocalProperties(androidDir);
	}

	static function generateRootBuildGradle(dir:String):Void {
		var lines = [
			"// Top-level build file for AUI Android project",
			"plugins {",
			'    id("com.android.application") version "8.7.3" apply false',
			'    id("org.jetbrains.kotlin.android") version "2.1.0" apply false',
			'    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false',
			"}",
			""
		];
		File.saveContent(dir + "/build.gradle.kts", lines.join("\n"));
	}

	static function generateSettings(dir:String, appName:String):Void {
		var lines = [
			"pluginManagement {",
			"    repositories {",
			"        google()",
			"        mavenCentral()",
			"        gradlePluginPortal()",
			"    }",
			"}",
			"dependencyResolutionManagement {",
			"    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)",
			"    repositories {",
			"        google()",
			"        mavenCentral()",
			"    }",
			"}",
			"",
			'rootProject.name = "' + appName + '"',
			'include(":app")',
			""
		];
		File.saveContent(dir + "/settings.gradle.kts", lines.join("\n"));
	}

	static function generateAppBuildGradle(dir:String, config:{
		appName:String,
		packageName:String,
		minSdk:Int,
		targetSdk:Int,
		compileSdk:Int,
		?android:AndroidPackagingConfig,
		/** The application declares a `Glance` surface, so the project needs
			the App Widget: its Jetpack Glance dependency, its receiver in the
			manifest, and the provider XML the receiver points at. **/
		?glanceWidget:Bool
	}):Void {
		// Optional ndk { abiFilters += listOf(...) } block, injected only when configured.
		var defaultConfigExtras:Array<String> = [];
		if (config.android != null && config.android.abiFilters != null && config.android.abiFilters.length > 0) {
			var quoted = config.android.abiFilters.map(function(s) return '"' + s + '"').join(", ");
			defaultConfigExtras.push("        ndk {");
			defaultConfigExtras.push("            abiFilters += listOf(" + quoted + ")");
			defaultConfigExtras.push("        }");
		}

		// Optional packaging { jniLibs { useLegacyPackaging = ... } } block.
		var packagingBlock:Array<String> = [];
		if (config.android != null && config.android.useLegacyPackaging == true) {
			packagingBlock.push("");
			packagingBlock.push("    packaging {");
			packagingBlock.push("        jniLibs {");
			packagingBlock.push("            useLegacyPackaging = true");
			packagingBlock.push("        }");
			packagingBlock.push("    }");
		}

		var lines = [
			"plugins {",
			'    id("com.android.application")',
			'    id("org.jetbrains.kotlin.android")',
			'    id("org.jetbrains.kotlin.plugin.compose")',
			"}",
			"",
			"android {",
			'    namespace = "' + config.packageName + '"',
			"    compileSdk = " + config.compileSdk,
			"",
			"    defaultConfig {",
			'        applicationId = "' + config.packageName + '"',
			"        minSdk = " + config.minSdk,
			"        targetSdk = " + config.targetSdk,
			"        versionCode = 1",
			'        versionName = "1.0"',
		].concat(defaultConfigExtras).concat([
			"    }",
			"",
			"    buildTypes {",
			"        release {",
			"            isMinifyEnabled = true",
			"            proguardFiles(",
			'                getDefaultProguardFile("proguard-android-optimize.txt"),',
			'                "proguard-rules.pro"',
			"            )",
			"        }",
			"    }",
		]).concat(packagingBlock).concat([
			"",
			"    compileOptions {",
			"        sourceCompatibility = JavaVersion.VERSION_17",
			"        targetCompatibility = JavaVersion.VERSION_17",
			"    }",
			"",
			"    kotlinOptions {",
			'        jvmTarget = "17"',
			"    }",
			"",
			"    buildFeatures {",
			"        compose = true",
			"    }",
		]).concat(kuiSourceSets()).concat([
			"}",
			"",
			"dependencies {",
			'    implementation(platform("androidx.compose:compose-bom:2024.12.01"))',
			'    implementation("androidx.compose.ui:ui")',
			'    implementation("androidx.compose.ui:ui-graphics")',
			'    implementation("androidx.compose.ui:ui-tooling-preview")',
			'    implementation("androidx.compose.material3:material3")',
			"    // The icons of the shared vocabulary Material ships in its core set;",
			"    // aui carries the rest as path data (runtime/AuiPictures.kt).",
			'    implementation("androidx.compose.material:material-icons-core")',
			'    implementation("androidx.activity:activity-compose:1.9.3")',
			'    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")',
			'    implementation("androidx.navigation:navigation-compose:2.8.5")',
			'    implementation("androidx.compose.foundation:foundation")',
		]).concat(config.glanceWidget == true ? [
			"",
			"    // The App Widget that draws @:surface(Glance). Only for an",
			"    // application that declares one: a widget nothing fills is a",
			"    // blank rectangle on someone's home screen.",
			'    implementation("androidx.glance:glance-appwidget:1.1.1")',
			"    // lifecycleScope, for the Activity to ask for a new sample as it leaves.",
			'    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.8.7")',
		] : []).concat([
			"",
			"    // Haxe JVM output",
			'    implementation(files("../../build/app-logic.jar"))',
		]).concat(kuiDependencies()).concat([
			"",
			'    debugImplementation("androidx.compose.ui:ui-tooling")',
			"}",
			""
		]);
		File.saveContent(dir + "/build.gradle.kts", lines.join("\n"));
	}

	/**
		The Kotlin a `kui` capability carries, compiled where it lives.

		Declared as `gradle: {sources: [...]}`, which `kui` has already resolved to
		absolute paths against the library root — so a capability shipped as a
		haxelib works without being copied into the project, which is the whole
		reason those paths are not relative to the working directory.

		Added as **source directories** rather than copied in. Copying would need a
		staleness rule of its own, and would put a second copy of someone else's
		Kotlin in a generated tree this file overwrites on every build. `srcDirs`
		leaves the file where its author maintains it.

		`java.srcDirs` and not `kotlin.srcDirs`: the Kotlin Android plugin compiles
		`.kt` found in the Java source sets, and that spelling has been stable across
		AGP versions where the `kotlin` accessor has not.
	**/
	static function kuiSourceSets():Array<String> {
		var directories = [];
		for (file in kui.macros.Emit.current().strings("gradle", "sources")) {
			var directory = haxe.io.Path.directory(file.replace("\\", "/"));
			if (directory != "" && directories.indexOf(directory) < 0) directories.push(directory);
		}
		if (directories.length == 0) return [];

		return [
			"",
			"    // Kotlin carried by kui capabilities, compiled where it lives",
			"    sourceSets {",
			'        getByName("main") {',
			"            java.srcDirs(" + [for (d in directories) '"' + d + '"'].join(", ") + ")",
			"        }",
			"    }",
		];
	}

	/** Maven coordinates a `kui` capability asked for, one `implementation` each. **/
	static function kuiDependencies():Array<String> {
		var coordinates = kui.macros.Emit.current().strings("gradle", "dependencies");
		if (coordinates.length == 0) return [];

		var lines = ["", "    // Asked for by kui capabilities"];
		for (coordinate in coordinates) lines.push('    implementation("' + coordinate + '")');
		return lines;
	}

	/**
		The permissions a `kui` capability needs, in the manifest.

		A capability that reads the battery, the camera or the location cannot ask
		for its own permission at runtime if the manifest never declared it — the
		request is refused before the user sees it. So the declaration travels with
		the capability rather than being something an application is expected to
		remember to add, and forgetting it becomes impossible rather than merely
		documented.

		The application's own entries are separate, and come from
		`aui.json#permissions` — see `permissionLines`. They have to come from
		somewhere the generator reads, because it overwrites the manifest on
		every build and one added there by hand would not survive.
	**/
	/**
		The manifest components a `kui` capability carries.

		Pasted inside `<application>`, verbatim. Some Android abilities are a
		declaration rather than a call — a `WearableListenerService` receives
		while the application is backgrounded, and one the manifest never named
		receives nothing — so the declaration has to travel with the capability
		like its permissions do.

		This generator overwrites the manifest on every build, so a component
		an author added by hand would not survive; a capability's does.
	**/
	/**
		What the application itself declares inside `<application>`, from
		`aui.json#components`.

		The twin of `aui.json#permissions`, and it exists for the same reason:
		this generator overwrites the manifest on every build, so a component
		an author added by hand is gone at the next one. Some things an
		application needs are a declaration rather than a call, and no
		capability knows about them — a `Service` an application runs itself is
		the case that asked for this. Its Kotlin is the application's, so its
		`<service>` line is too.

		Each entry is pasted verbatim, indented into place. Nothing is parsed
		or validated: Android's own manifest merger is the authority on what is
		legal there, and a second opinion here would only be wrong later.
	**/
	static function appComponents(app:Null<Array<String>>):Array<String> {
		if (app == null || app.length == 0)
			return [];
		var lines = ["", "        <!-- Declared by the application (aui.json#components) -->"];
		for (fragment in app)
			for (line in fragment.split("\n"))
				lines.push("        " + line);
		return lines;
	}

	/**
		The manifest components a `kui` capability carries.
	**/
	static function kuiComponents():Array<String> {
		var fragments = kui.macros.Emit.current().strings("gradle", "components");
		if (fragments.length == 0) return [];

		var lines = ["", "        <!-- Declared by kui capabilities -->"];
		for (fragment in fragments)
			for (line in fragment.split("\n"))
				lines.push("        " + line);
		return lines;
	}

	/**
		What the application itself asks for, from `aui.json#permissions`.

		Not everything an application needs travels with a capability. An app
		that opens a socket of its own needs `android.permission.INTERNET`,
		and nothing in `kui` knows that it does — the sockets are Haxe's. So
		an application states its own, in the file it already configures
		itself from, and the generator writes them where a hand-edited
		manifest would have been overwritten.
	**/
	/**
		Every `<uses-permission>` the manifest needs, each written once.

		The application asks for some and its capabilities bring others, and
		the two lists overlap the moment an application uses a capability for
		the very thing it also asked for — `INTERNET`, in the first case that
		showed this. A repeated `<uses-permission>` is legal and Android
		ignores the second, but the manifest then reads as if two authors
		disagreed, and a person auditing what an application may do has to
		notice that they did not.

		The application's come first, because that is the order a reader
		expects: what this app asks for, then what it asks for through
		somebody else.
	**/
	static function permissionLines(app:Null<Array<String>>):Array<String> {
		var seen = new Map<String, Bool>();
		var lines:Array<String> = [];

		function group(header:String, names:Array<String>):Void {
			var fresh = [for (n in names) if (!seen.exists(n)) n];
			if (fresh.length == 0)
				return;
			lines.push(header);
			for (n in fresh) {
				seen.set(n, true);
				lines.push('    <uses-permission android:name="' + n + '" />');
			}
			lines.push("");
		}

		group("    <!-- Asked for by the application (aui.json#permissions) -->", app == null ? [] : app);
		group("    <!-- Needed by kui capabilities -->", kui.macros.Emit.current().strings("gradle", "permissions"));
		return lines;
	}

	static function generateManifest(srcDir:String, config:{
		appName:String,
		packageName:String,
		?permissions:Array<String>,
		?components:Array<String>,
		minSdk:Int,
		targetSdk:Int,
		compileSdk:Int,
		?android:AndroidPackagingConfig,
		/** The application declares a `Glance` surface, so the project needs
			the App Widget: its Jetpack Glance dependency, its receiver in the
			manifest, and the provider XML the receiver points at. **/
		?glanceWidget:Bool
	}):Void {
		var safeName = sanitizeName(config.appName);
		// Optional android:extractNativeLibs attribute.
		var applicationAttrs:Array<String> = [
			'        android:allowBackup="true"',
		];
		if (config.android != null && config.android.extractNativeLibs == true) {
			applicationAttrs.push('        android:extractNativeLibs="true"');
		}
		applicationAttrs.push('        android:label="' + config.appName + '"');
		applicationAttrs.push('        android:supportsRtl="true"');
		applicationAttrs.push('        android:theme="@style/Theme.' + safeName + '">');

		var lines = [
			'<?xml version="1.0" encoding="utf-8"?>',
			'<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
			"",
		].concat(permissionLines(config.permissions)).concat([
			"    <application",
		]).concat(applicationAttrs).concat([
			"        <activity",
			'            android:name="' + config.packageName + '.MainActivity"',
			'            android:exported="true"',
			'            android:theme="@style/Theme.' + safeName + '">',
			"            <intent-filter>",
			'                <action android:name="android.intent.action.MAIN" />',
			'                <category android:name="android.intent.category.LAUNCHER" />',
			"            </intent-filter>",
			"        </activity>",
		]).concat(config.glanceWidget == true ? [
			"",
			"        <!-- The App Widget drawing @:surface(Glance). exported, because",
			"             the launcher is another application and must be able to",
			"             bind it; it carries no data of its own. -->",
			"        <receiver",
			'            android:name="' + config.packageName + '.AuiGlanceReceiver"',
			'            android:exported="true">',
			"            <intent-filter>",
			'                <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />',
			"            </intent-filter>",
			"            <meta-data",
			'                android:name="android.appwidget.provider"',
			'                android:resource="@xml/aui_glance_widget_info" />',
			"        </receiver>",
		] : []).concat(appComponents(config.components)).concat(kuiComponents()).concat([
			"    </application>",
			"",
			"</manifest>",
			""
		]);
		File.saveContent(srcDir + "/AndroidManifest.xml", lines.join("\n"));

		if (config.glanceWidget == true) generateGlanceWidgetInfo(srcDir);
	}

	/**
		What the launcher needs to know before it ever asks for content: how
		big the widget wants to be, and how often the system should offer to
		refresh it.

		`updatePeriodMillis` is 0 on purpose — the platform's own period has a
		30-minute floor and would be the only thing driving a surface whose
		whole point is to be current. The application asks for an update when
		it has something to show; the snapshot is sampled then.
	**/
	static function generateGlanceWidgetInfo(srcDir:String):Void {
		ensureDir(srcDir + "/res/xml");
		var lines = [
			'<?xml version="1.0" encoding="utf-8"?>',
			'<appwidget-provider xmlns:android="http://schemas.android.com/apk/res/android"',
			'    android:minWidth="180dp"',
			'    android:minHeight="110dp"',
			'    android:updatePeriodMillis="0"',
			'    android:resizeMode="horizontal|vertical"',
			'    android:widgetCategory="home_screen" />',
			""
		];
		File.saveContent(srcDir + "/res/xml/aui_glance_widget_info.xml", lines.join("\n"));
	}

	static function generateGradleWrapper(dir:String):Void {
		ensureDir(dir + "/gradle/wrapper");
		var lines = [
			"distributionBase=GRADLE_USER_HOME",
			"distributionPath=wrapper/dists",
			"distributionUrl=https\\://services.gradle.org/distributions/gradle-8.11.1-bin.zip",
			"zipStoreBase=GRADLE_USER_HOME",
			"zipStorePath=wrapper/dists",
			""
		];
		File.saveContent(dir + "/gradle/wrapper/gradle-wrapper.properties", lines.join("\n"));
	}

	static function generateTheme(srcDir:String, appName:String):Void {
		var safeName = sanitizeName(appName);
		var lines = [
			'<?xml version="1.0" encoding="utf-8"?>',
			"<resources>",
			'    <style name="Theme.' + safeName + '" parent="android:Theme.Material.Light.NoActionBar" />',
			"</resources>",
			""
		];
		File.saveContent(srcDir + "/res/values/themes.xml", lines.join("\n"));
	}

	static function generateProguard(dir:String):Void {
		var lines = [
			"# AUI ProGuard Rules",
			"# Keep Haxe runtime classes",
			"-keep class haxe.** { *; }",
			"-keep class _** { *; }",
			""
		];
		File.saveContent(dir + "/proguard-rules.pro", lines.join("\n"));
	}

	static function generateGradleProperties(dir:String):Void {
		var lines = [
			"org.gradle.jvmargs=-Xmx2048m -Dfile.encoding=UTF-8",
			"android.useAndroidX=true",
			"kotlin.code.style=official",
			"android.nonTransitiveRClass=true",
			""
		];
		File.saveContent(dir + "/gradle.properties", lines.join("\n"));
	}

	static function generateLocalProperties(dir:String):Void {
		// Detect Android SDK location
		var sdkDir = Sys.getEnv("ANDROID_HOME");
		if (sdkDir == null || sdkDir == "") {
			sdkDir = Sys.getEnv("ANDROID_SDK_ROOT");
		}
		if (sdkDir == null || sdkDir == "") {
			// Common default locations
			var home = Sys.getEnv("HOME");
			if (home != null) {
				var defaultPath = home + "/Library/Android/sdk";
				if (FileSystem.exists(defaultPath)) {
					sdkDir = defaultPath;
				}
			}
		}
		if (sdkDir != null && sdkDir != "") {
			File.saveContent(dir + "/local.properties", "sdk.dir=" + sdkDir + "\n");
		}
	}

	static function sanitizeName(name:String):String {
		return ~/[^a-zA-Z0-9]/g.replace(name, "");
	}

	static function ensureDir(path:String):Void {
		if (!FileSystem.exists(path)) {
			var parts = path.split("/");
			var current = "";
			for (part in parts) {
				current += part + "/";
				if (!FileSystem.exists(current)) {
					FileSystem.createDirectory(current);
				}
			}
		}
	}
}
#end
