package aui.kui;

/**
	Which platform an `aui` build is for, told to `kui`.

	Called once from the build file:

	```
	--macro aui.kui.Platform.registerWithKui()
	```

	`aui` is the one backend with nothing to decide: it targets Android and only
	Android. The registration is still explicit, because `kui` is handed a
	backend's name rather than its knowledge — a macro cannot call a function it
	was only given the name of, which is why `mui.macros.Backend.register` takes
	the same shape.

	## One toolchain, and not hxcpp

	`aui` compiles Haxe to the JVM — `--jvm build/app-logic.jar` — and Gradle
	performs every link there is. So a capability reaching Android through `aui`
	carries a `gradle` payload: Kotlin sources, Maven coordinates, manifest
	permissions.

	`pui` reaches the same platform differently, through hxcpp and the NDK, and
	registers `["hxcpp", "gradle"]` for it. Same operating system, two link
	stories — which is why `kui.build.Payload` is keyed by toolchain and not by
	platform, and why an Android capability may need to say both things.
**/
class Platform {
	/** Hand `kui` the platform and the link step this build has. **/
	public static function registerWithKui():Void {
		#if macro
		kui.macros.Host.register({
			platform: "android",
			toolchains: ["gradle"],
			backend: "aui",
		});
		#end
	}
}
