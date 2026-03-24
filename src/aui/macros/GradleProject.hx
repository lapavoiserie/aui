package aui.macros;

#if macro
import sys.FileSystem;
import sys.io.File;

class GradleProject {
	public static function generate(config:{
		appName:String,
		packageName:String,
		minSdk:Int,
		targetSdk:Int,
		compileSdk:Int
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
		compileSdk:Int
	}):Void {
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
			"}",
			"",
			"dependencies {",
			'    implementation(platform("androidx.compose:compose-bom:2024.12.01"))',
			'    implementation("androidx.compose.ui:ui")',
			'    implementation("androidx.compose.ui:ui-graphics")',
			'    implementation("androidx.compose.ui:ui-tooling-preview")',
			'    implementation("androidx.compose.material3:material3")',
			'    implementation("androidx.activity:activity-compose:1.9.3")',
			'    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:2.8.7")',
			'    implementation("androidx.navigation:navigation-compose:2.8.5")',
			'    implementation("androidx.compose.foundation:foundation")',
			"",
			"    // Haxe JVM output",
			'    implementation(files("../../build/app-logic.jar"))',
			"",
			'    debugImplementation("androidx.compose.ui:ui-tooling")',
			"}",
			""
		];
		File.saveContent(dir + "/build.gradle.kts", lines.join("\n"));
	}

	static function generateManifest(srcDir:String, config:{
		appName:String,
		packageName:String,
		minSdk:Int,
		targetSdk:Int,
		compileSdk:Int
	}):Void {
		var safeName = sanitizeName(config.appName);
		var lines = [
			'<?xml version="1.0" encoding="utf-8"?>',
			'<manifest xmlns:android="http://schemas.android.com/apk/res/android">',
			"",
			"    <application",
			'        android:allowBackup="true"',
			'        android:label="' + config.appName + '"',
			'        android:supportsRtl="true"',
			'        android:theme="@style/Theme.' + safeName + '">',
			"        <activity",
			'            android:name="' + config.packageName + '.MainActivity"',
			'            android:exported="true"',
			'            android:theme="@style/Theme.' + safeName + '">',
			"            <intent-filter>",
			'                <action android:name="android.intent.action.MAIN" />',
			'                <category android:name="android.intent.category.LAUNCHER" />',
			"            </intent-filter>",
			"        </activity>",
			"    </application>",
			"",
			"</manifest>",
			""
		];
		File.saveContent(srcDir + "/AndroidManifest.xml", lines.join("\n"));
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
