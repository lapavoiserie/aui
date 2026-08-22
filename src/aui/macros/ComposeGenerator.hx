package aui.macros;

#if macro
import haxe.macro.Compiler;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import sys.FileSystem;
import sys.io.File;

class ComposeGenerator {
	static var _appClass:Null<String> = null;
	static var _appModule:Null<String> = null;
	// Classes reaching aui.App, and each one's direct parent — see `resolveApp`.
	static var _appCandidates:Array<{name:String, module:String, parent:Null<String>}> = [];
	static var _observableClasses:Array<String> = [];
	static var _viewComponents:Array<String> = [];
	static var _outputDir:String = "android/app/src/main/kotlin/com/aui/generated";
	static var _indent:Int = 0;
	// State fields detected on the App subclass: {name, kotlinType, defaultValue}
	static var _stateFields:Array<{name:String, type:String, defaultValue:String}> = [];
	// Navigation routes collected during AST walking
	static var _navRoutes:Array<{id:String, bodyExpr:TypedExpr}> = [];
	static var _nextRouteId:Int = 0;
	static var _hasNavigation:Bool = false;
	static var _hasTabView:Bool = false;
	// Local bindings for inlining view-returning function calls (param ID → arg expr)
	static var _localBindings:Map<Int, TypedExpr> = new Map();
	// Lambda parameters currently in Kotlin scope (param ID → Kotlin identifier).
	// Populated when entering closure-form ForEach bodies so TLocal refs to the
	// lambda parameter resolve to their declared name instead of falling through
	// to the empty fallback -- which emitted `text = ` with nothing after it, not
	// even valid Kotlin.
	static var _lambdaParamIds:Map<Int, String> = new Map();

	public static function register():Void {
		// aui compiles for Android, so say so.
		//
		// Haxe's JVM `EReg` adds `Pattern.UNICODE_CHARACTER_CLASS` unless the
		// `android` define is set -- a flag Android's regex engine rejects
		// outright. Any class holding a regex literal then fails its static
		// initialiser, so the class cannot be loaded *at all*: `aui.ui.Text` has
		// one, and every app that reaches a Text at runtime dies with
		// `ExceptionInInitializerError`.
		//
		// It stayed invisible because the static path never runs this code --
		// the generator reads `body()` at compile time and emits Kotlin, so
		// `aui.ui.Text` ships in the jar and is never touched. The dynamic
		// renderer is the first thing to actually execute it, and it crashed on
		// the emulator at the first frame.
		Compiler.define("android");

		// The view rule, enforced from here rather than asked for in every
		// build.hxml. A fundamental rule an example can forget to opt into is
		// advice, not a rule: registering it beside the generator means any
		// build that emits Compose is checked, by construction.
		rui.macros.ViewRule.register("aui.App", "body");

		// Which renderer this build targets. Asked once, here, so the
		// deprecation warning a static build earns lands at the top of its
		// output rather than beside whichever branch happened to run first.
		var isDynamic = RenderPath.isDynamic();

		// The dynamic renderer's Haxe half is reached only from Kotlin, so
		// nothing in Haxe references it and it would never enter the build --
		// nor survive DCE. Pull it in explicitly, as sui does for its own.
		if (isDynamic) {
			Context.getModule("aui.runtime.ViewNodeBridge");
		}

		// Refuse a view the dynamic renderer cannot draw.
		if (isDynamic) {
			Context.onAfterTyping(checkDynamicCoverage);
		}

		Context.onAfterTyping(function(modules:Array<ModuleType>) {
			for (module in modules) {
				switch (module) {
					case TClassDecl(ref):
						var cls = ref.get();
						var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;

						// Every class whose chain reaches aui.App is a candidate, and
						// there can be more than one: `mui.App` extends it so a mui
						// application has two. Taking the last one seen instantiated
						// the intermediate, whose body() is the inherited default --
						// the app drew "?EmptyView" and nothing said why. So they are
						// collected, and the one nobody extends wins.
						var superClass = cls.superClass;
						while (superClass != null) {
							var superRef = superClass.t.get();
							var superName = superRef.pack.join(".") + (superRef.pack.length > 0 ? "." : "") + superRef.name;
							if (superName == "aui.App") {
								_appCandidates.push({name: fullName, module: cls.module, parent: parentName(cls)});
								break;
							}
							superClass = superRef.superClass;
						}

						var superClass2 = cls.superClass;
						while (superClass2 != null) {
							var superRef = superClass2.t.get();
							var superName = superRef.pack.join(".") + (superRef.pack.length > 0 ? "." : "") + superRef.name;
							if (superName == "aui.state.Observable") {
								_observableClasses.push(fullName);
								break;
							}
							superClass2 = superRef.superClass;
						}
					default:
				}
			}
		});

		Context.onAfterGenerate(function() {
			resolveApp();
			if (_appClass == null) return;
			generateComposeFiles();
		});
	}

	static function parentName(cls:ClassType):Null<String> {
		if (cls.superClass == null) return null;
		var p = cls.superClass.t.get();
		return p.pack.join(".") + (p.pack.length > 0 ? "." : "") + p.name;
	}

	/**
		The application to instantiate: the candidate nobody extends.

		A framework layered over aui — `mui` is one — declares its own `App`
		between the user's and ours, so two classes answer "is this an aui.App".
		Only one of them has a `body()` worth running, and it is the leaf.
	**/
	static function resolveApp():Void {
		if (_appCandidates.length == 0) return;

		var extended = new Map<String, Bool>();
		for (candidate in _appCandidates) {
			if (candidate.parent != null) extended.set(candidate.parent, true);
		}

		for (candidate in _appCandidates) {
			if (!extended.exists(candidate.name)) {
				_appClass = candidate.name;
				_appModule = candidate.module;
				return;
			}
		}

		// Every candidate is extended by another: a cycle is impossible here, so
		// this means several leaves. Take the first and say so, rather than
		// picking silently.
		_appClass = _appCandidates[0].name;
		_appModule = _appCandidates[0].module;
		Context.warning('[AUI] several application classes found; building ' + _appClass, Context.currentPos());
	}

	static function generateComposeFiles():Void {
		ensureDir(_outputDir);

		var appType = Context.getType(_appClass);
		var appName = "HaxeApp";
		var packageName = "com.haxe.app";
		var minSdk = 24;
		var targetSdk = 35;
		var compileSdk = 35;

		var androidConfig:Null<AndroidPackagingConfig> = null;
		if (FileSystem.exists("aui.json")) {
			try {
				var json = haxe.Json.parse(File.getContent("aui.json"));
				if (json.appName != null) appName = json.appName;
				if (json.packageName != null) packageName = json.packageName;
				if (json.minSdk != null) minSdk = json.minSdk;
				if (json.targetSdk != null) targetSdk = json.targetSdk;
				if (json.compileSdk != null) compileSdk = json.compileSdk;
				if (json.android != null) androidConfig = json.android;
			} catch (e:Dynamic) {}
		}

		// Collect state fields from the App subclass
		_stateFields = collectStateFields(appType);

		// Always (re)generate the Gradle project files: inexpensive idempotent overwrites
		// of build.gradle.kts / manifest / themes. Lets aui.json#android changes propagate
		// without forcing the user to delete android/. The wrapper jar (created by gradle wrapper)
		// is left untouched.
		var firstGenerate = !FileSystem.exists("android/build.gradle.kts");
		GradleProject.generate({
			appName: appName,
			packageName: packageName,
			minSdk: minSdk,
			targetSdk: targetSdk,
			compileSdk: compileSdk,
			android: androidConfig
		});
		if (firstGenerate) {
			Context.warning('[AUI] Generated Android project in android/', Context.currentPos());
		}

		generateMainActivity(packageName, appName);

		// The static screen is what the transpiler exists for -- and on the
		// dynamic path nothing uses it: MainActivity calls DynamicRoot(), which
		// walks the live tree.
		//
		// Emitting it anyway was worse than wasteful. LiveProps rewrites the view
		// expressions before this walk sees them, so what came out was an empty
		// `Column` -- a screen that would render nothing at all if anyone wired
		// it. And it is this walk that turns an expression the transpiler cannot
		// translate into invalid Kotlin, breaking a build that had no use for the
		// file.
		var screen = _outputDir + "/MainScreen.kt";
		if (RenderPath.isStatic()) {
			generateMainScreen(packageName, appType);
		} else if (FileSystem.exists(screen)) {
			// Left over from a static build: stale, and now misleading.
			FileSystem.deleteFile(screen);
		}

		// Emit Kotlin runtime helpers (StateBridge, etc.) alongside the user's
		// generated Compose files. These are consumed by the Haxe state classes
		// at runtime — the JVM class loader pairs them up regardless of source
		// origin, both end up in the same APK.
		writeAuiRuntimeKotlin();

		// Sync native libs and assets declared in aui.json#android on every build.
		if (androidConfig != null) syncNativeBundle(androidConfig);

		Context.warning('[AUI] Generated Compose files in ${_outputDir}', Context.currentPos());
	}

	static function collectStateFields(appType:Type):Array<{name:String, type:String, defaultValue:String}> {
		var fields:Array<{name:String, type:String, defaultValue:String}> = [];

		switch (appType) {
			case TInst(ref, _):
				var cls = ref.get();

				// First, collect state field names and types
				for (field in cls.fields.get()) {
					switch (field.type) {
						case TInst(tref, params):
							var typeName = tref.get().pack.join(".") + (tref.get().pack.length > 0 ? "." : "") + tref.get().name;
							if (typeName == "aui.state.State" && params.length > 0) {
								var kotlinType = haxeTypeToKotlin(params[0]);
								fields.push({name: field.name, type: kotlinType, defaultValue: getDefaultForKotlinType(kotlinType)});
							}
						default:
					}
				}

				// Scan constructor for `new State<T>(defaultVal, name)` to extract defaults
				var ctor = cls.constructor;
				if (ctor != null) {
					var ctorExpr = ctor.get().expr();
					if (ctorExpr != null) {
						scanConstructorForDefaults(ctorExpr, fields);
					}
				}
			default:
		}

		return fields;
	}

	static function scanConstructorForDefaults(expr:TypedExpr, fields:Array<{name:String, type:String, defaultValue:String}>):Void {
		if (expr == null) return;
		switch (expr.expr) {
			case TFunction(tf):
				scanConstructorForDefaults(tf.expr, fields);
			case TBlock(exprs):
				for (e in exprs) {
					scanConstructorForDefaults(e, fields);
				}
			case TBinop(op, e1, e2):
				// Look for: this.fieldName = new State<T>(defaultVal, name)
				var fieldName:Null<String> = null;
				switch (e1.expr) {
					case TField(_, fa): fieldName = getFieldName(fa);
					default:
				}
				if (fieldName != null) {
					var newExpr = findNewState(e2);
					if (newExpr != null) {
						var found = false;
						for (i in 0...fields.length) {
							if (fields[i].name == fieldName) {
								fields[i] = {name: fields[i].name, type: fields[i].type, defaultValue: newExpr};
								found = true;
								break;
							}
						}
					}
				}
				scanConstructorForDefaults(e2, fields);
			default:
		}
	}

	// Recursively search for `new State<T>(default, name)` and extract default
	static function findNewState(expr:TypedExpr):Null<String> {
		if (expr == null) return null;
		switch (expr.expr) {
			case TNew(classRef, _, args):
				var cls = classRef.get();
				var name = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
				if (name == "aui.state.State" && args.length >= 1) {
				return extractDefaultValue(args[0]);
				}
				return null;
			case TBlock(exprs):
				for (e in exprs) {
					var r = findNewState(e);
					if (r != null) return r;
				}
				return null;
			case TReturn(e):
				return findNewState(e);
			default:
				return null;
		}
	}

	static function extractDefaultValue(expr:TypedExpr):Null<String> {
		if (expr == null) return null;
		switch (expr.expr) {
			case TConst(c):
				switch (c) {
					case TInt(i): return Std.string(i);
					case TFloat(f): return f + "f";
					case TString(s): return '"${escapeString(s)}"';
					case TBool(b): return b ? "true" : "false";
					default: return null;
				}
			case TNew(_, _, args):
				// new State<T>(defaultValue, name) — first arg is the default
				if (args.length > 0) return extractDefaultValue(args[0]);
				return null;
			case TFunction(tf):
				return extractDefaultValue(tf.expr);
			case TReturn(e):
				if (e != null) return extractDefaultValue(e);
				return null;
			case TBlock(exprs):
				for (e in exprs) {
					var v = extractDefaultValue(e);
					if (v != null) return v;
				}
				return null;
			default:
				return null;
		}
	}

	// -------------------------------------------------------------------------
	// JVM class name resolution
	// -------------------------------------------------------------------------

	// hxjava maps default-package classes to `haxe.root.<Name>`. Packaged
	// classes pass through unchanged. This is the convention emitted by Haxe's
	// `--jvm` target as of 4.3.x; if it changes, this single helper is the
	// only thing to update.
	static function jvmClassName(haxeName:String):String {
		return (haxeName.indexOf(".") < 0) ? "haxe.root." + haxeName : haxeName;
	}

	// Returns the Haxe-side App class name (cached during onAfterTyping).
	static function appJvmName():String {
		return jvmClassName(_appClass);
	}

	// -------------------------------------------------------------------------
	// State read / write emitters
	//
	// State is owned by the Haxe App instance and backed by Compose
	// MutableState through aui.state.StateBridge. Reads inside @Composable
	// are tracked; writes from anywhere (including lifted closures running
	// as JVM bytecode) trigger recomposition.
	// -------------------------------------------------------------------------

	static function stateKotlinType(name:String):String {
		for (sf in _stateFields) {
			if (sf.name == name) return sf.type;
		}
		return "Any?";
	}

	// Read with Kotlin-side cast to the declared type. Used when the value is
	// fed to a typed Compose API (OutlinedTextField, Slider, etc.).
	static function stateRead(name:String):String {
		return "(app." + name + ".get() as " + stateKotlinType(name) + ")";
	}

	// Read for use inside Kotlin string interpolation `${...}` — toString happens
	// anyway, no cast needed.
	static function stateReadForInterp(name:String):String {
		return "app." + name + ".get()";
	}

	static function stateAssign(name:String, valueExpr:String):String {
		return "app." + name + ".set(" + valueExpr + ")";
	}

	// -------------------------------------------------------------------------
	// File generators
	// -------------------------------------------------------------------------

	static function generateMainActivity(packageName:String, appName:String):Void {
		var jvmApp = appJvmName();
		var lines = [
			"package " + packageName,
			"",
			"import android.os.Bundle",
			"import androidx.activity.ComponentActivity",
			"import androidx.activity.compose.setContent",
			"import androidx.activity.viewModels",
			"import androidx.compose.material3.MaterialTheme",
			"import androidx.compose.material3.Surface",
			"import androidx.lifecycle.ViewModel",
			"",
			"/**",
			" * Holds the Haxe App across configuration changes.",
			" *",
			" * Android destroys and recreates the Activity when the device",
			" * rotates. Building the app in onCreate therefore built a SECOND",
			" * one on every rotation: its @:state fields went back to their",
			" * initialisers (the counter you were looking at reset itself), the",
			" * previous instance's effects kept running with nobody watching,",
			" * and aui.state.State's name registry silently repointed to the",
			" * newest cells.",
			" *",
			" * A ViewModel outlives configuration changes and is cleared only",
			" * when the Activity is really finishing — which is exactly the",
			" * distinction the app needs, and the one Android does not make for",
			" * you. onCleared is therefore the one place release() belongs.",
			" */",
			"class AuiAppHolder : ViewModel() {",
			"    var app: " + jvmApp + "? = null",
			"",
			"    override fun onCleared() {",
			"        super.onCleared()",
			"        aui.runtime.ViewNodeBridge.releaseApp()",
			"        app = null",
			"    }",
			"}",
			"",
			"class MainActivity : ComponentActivity() {",
			"    private val holder: AuiAppHolder by viewModels()",
			"",
			"    override fun onCreate(savedInstanceState: Bundle?) {",
			"        super.onCreate(savedInstanceState)",
			"        // The retained app, or a new one the first time round. On a",
			"        // rotation this branch is not taken: same instance, same",
			"        // @:state cells, same effects — the screen comes back where",
			"        // it was.",
			"        // A val, not a var: the composition lambda below captures it,",
			"        // and a captured var would lose its smart cast to non-null.",
			"        val app = holder.app ?: run {",
			"            // Constructing it initializes its @:state fields, each",
			"            // backed by a Compose MutableState via aui.state.StateBridge.",
			"            val fresh = " + jvmApp + "()",
			"            // AUI lifecycle hook: invoked once before composition, gives",
			"            // the app a chance to bootstrap with the Android Context",
			"            // (extract assets, set up symlinks, register JNI bridges).",
			"            // Once per app, not once per Activity — and read from the",
			"            // application context, never this Activity: what the app is",
			"            // handed here it may hold, and it now outlives the Activity",
			"            // that created it.",
			"            fresh.onAndroidContextReady(",
			"                applicationInfo.nativeLibraryDir,",
			"                applicationContext.filesDir.absolutePath,",
			"                applicationContext.assets",
			"            )",
			"            holder.app = fresh",
			"            fresh",
			"        }",
		];

		// The dynamic path walks the tree the app builds while running, instead
		// of the Kotlin the generator emitted from the typed AST. Same app, same
		// body(): what changes is who reads it, and when.
		if (RenderPath.isDynamic()) {
			lines.push("        // Hand the app to the Haxe-side tree reader, which");
			lines.push("        // DynamicRoot() walks through nui's pull contract.");
			lines.push("        aui.runtime.ViewNodeBridge.setApp(app)");
			lines.push("        setContent {");
			lines.push("            MaterialTheme {");
			lines.push("                Surface {");
			lines.push("                    aui.runtime.DynamicRoot()");
			lines.push("                }");
			lines.push("            }");
			lines.push("        }");
		} else {
			lines.push("        setContent {");
			lines.push("            MaterialTheme {");
			lines.push("                Surface {");
			lines.push("                    MainScreen(app)");
			lines.push("                }");
			lines.push("            }");
			lines.push("        }");
		}

		lines.push("    }");
		lines.push("}");
		lines.push("");
		File.saveContent(_outputDir + "/MainActivity.kt", lines.join("\n"));
	}

	static function generateMainScreen(packageName:String, appType:Type):Void {
		var bodyExpr:Null<TypedExpr> = null;

		switch (appType) {
			case TInst(ref, _):
				var cls = ref.get();
				for (field in cls.fields.get()) {
					if (field.name == "body") {
						bodyExpr = field.expr();
						break;
					}
				}
			default:
		}

		// Reset navigation state
		_navRoutes = [];
		_nextRouteId = 0;
		_hasNavigation = false;
		_hasTabView = false;

		// Pre-scan for navigation elements
		if (bodyExpr != null) {
			scanForNavigation(bodyExpr);
		}

		var buf = new StringBuf();
		buf.add("package " + packageName + "\n\n");

		var imports = [
			"androidx.compose.foundation.layout.*",
			"androidx.compose.foundation.lazy.LazyColumn",
			"androidx.compose.foundation.lazy.items",
			"androidx.compose.foundation.rememberScrollState",
			"androidx.compose.foundation.verticalScroll",
			"androidx.compose.material.icons.Icons",
			"androidx.compose.material.icons.filled.*",
			"androidx.compose.material3.*",
			"androidx.compose.runtime.*",
			"androidx.compose.ui.Alignment",
			"androidx.compose.ui.Modifier",
			"androidx.compose.ui.unit.dp",
			"androidx.compose.ui.unit.sp",
			"androidx.compose.ui.graphics.Color",
			"androidx.compose.ui.graphics.vector.ImageVector",
			"androidx.compose.ui.text.font.FontWeight",
			"androidx.compose.ui.text.font.FontStyle",
			"androidx.compose.ui.text.style.TextAlign",
			"androidx.compose.ui.text.input.PasswordVisualTransformation",
			"androidx.compose.foundation.background",
			"androidx.compose.foundation.border",
			"androidx.compose.foundation.clickable",
			"androidx.compose.foundation.shape.RoundedCornerShape",
			"androidx.compose.foundation.shape.CircleShape",
			"androidx.compose.ui.draw.*"
		];
		if (_hasNavigation) {
			imports.push("androidx.navigation.compose.NavHost");
			imports.push("androidx.navigation.compose.composable");
			imports.push("androidx.navigation.compose.rememberNavController");
		}
		for (imp in imports) buf.add("import " + imp + "\n");
		buf.add("\n");

		buf.add("@Composable\n");
		buf.add("fun MainScreen(app: " + appJvmName() + ") {\n");

		// State fields are no longer declared as `var X by remember { mutableStateOf(...) }`.
		// They live on the Haxe App instance (`app.X`), each backed by a Compose
		// MutableState (created in the Haxe State<T> constructor through StateBridge).
		// Reads via `app.X.get()` are observed by Compose; writes via `app.X.set(...)`
		// trigger recomposition — including writes from lifted closures running as
		// pure JVM bytecode.

		if (_hasNavigation) {
			buf.add("    val navController = rememberNavController()\n\n");
		}

		if (bodyExpr != null) {
			_indent = 1;
			buf.add(translateTypedExpr(bodyExpr));
		} else {
			buf.add('    Text("Hello from AUI!")\n');
		}

		buf.add("}\n");

		File.saveContent(_outputDir + "/MainScreen.kt", buf.toString());
	}

	// Pre-scan the AST for NavigationStack/NavigationLink to set up routes
	static function scanForNavigation(expr:TypedExpr):Void {
		if (expr == null) return;
		switch (expr.expr) {
			case TNew(classRef, _, args):
				var cls = classRef.get();
				var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
				if (fullName == "aui.ui.NavigationStack") {
					_hasNavigation = true;
				}
				if (fullName == "aui.ui.TabView") {
					_hasTabView = true;
				}
				if (fullName == "aui.ui.NavigationLink" && args.length >= 2) {
					var routeId = "screen_" + _nextRouteId++;
					_navRoutes.push({id: routeId, bodyExpr: args[1]});
				}
				for (arg in args) scanForNavigation(arg);
			case TCall(func, args):
				scanForNavigation(func);
				for (arg in args) scanForNavigation(arg);
			case TBlock(exprs):
				for (e in exprs) scanForNavigation(e);
			case TFunction(tf):
				scanForNavigation(tf.expr);
			case TReturn(e):
				if (e != null) scanForNavigation(e);
			case TField(e, _):
				scanForNavigation(e);
			case TArrayDecl(exprs):
				for (e in exprs) scanForNavigation(e);
			default:
		}
	}

	// -------------------------------------------------------------------------
	// View-returning function inlining
	// -------------------------------------------------------------------------

	static function returnsView(field:ClassField):Bool {
		switch (field.type) {
			case TFun(_, ret):
				switch (ret) {
					case TInst(ref, _):
						var cls = ref.get();
						if (cls.name == "View" && cls.pack.join(".") == "aui") return true;
						var sc = cls.superClass;
						while (sc != null) {
							var scCls = sc.t.get();
							if (scCls.name == "View" && scCls.pack.join(".") == "aui") return true;
							sc = scCls.superClass;
						}
					default:
				}
			default:
		}
		return false;
	}

	static function tryInlineViewCall(func:TypedExpr, args:Array<TypedExpr>):Null<String> {
		switch (func.expr) {
			case TField(_, fa):
				switch (fa) {
					case FInstance(_, _, fieldRef):
						var field = fieldRef.get();
						// Skip modifier methods and known View/framework methods
						if (isModifierMethod(field.name)) return null;
						if (isFrameworkMethod(field.name)) return null;
						if (returnsView(field)) return inlineViewFunction(field, args);

					case FStatic(_, fieldRef):
						var field = fieldRef.get();
						if (isModifierMethod(field.name)) return null;
						if (returnsView(field)) return inlineViewFunction(field, args);

					case FClosure(_, fieldRef):
						var field = fieldRef.get();
						if (isModifierMethod(field.name)) return null;
						if (returnsView(field)) return inlineViewFunction(field, args);

					default:
				}
			default:
		}
		return null;
	}

	static function isFrameworkMethod(name:String):Bool {
		return ["body", "push", "pop", "get", "set", "toString", "new"].indexOf(name) != -1;
	}

	static function inlineViewFunction(field:ClassField, args:Array<TypedExpr>):Null<String> {
		var funcExpr = field.expr();
		if (funcExpr == null) return null;

		// Save and set up local bindings for parameters
		var savedBindings = _localBindings.copy();

		switch (funcExpr.expr) {
			case TFunction(f):
				for (i in 0...f.args.length) {
					if (i < args.length) {
						_localBindings.set(f.args[i].v.id, args[i]);
					}
				}
			default:
		}

		var result = translateTypedExpr(funcExpr);

		// Restore previous bindings
		_localBindings = savedBindings;

		return result;
	}

	// -------------------------------------------------------------------------
	// AST Translation
	// -------------------------------------------------------------------------

	static function translateTypedExpr(expr:TypedExpr):String {
		if (expr == null) return "";

		switch (expr.expr) {
			case TFunction(tfunc):
				return translateTypedExpr(tfunc.expr);

			case TReturn(e):
				if (e != null) return translateTypedExpr(e);
				return "";

			case TNew(classRef, _, args):
				var cls = classRef.get();
				var fullName = resolveAuiClassName(cls);
				return translateViewWithModifiers(fullName, args, []);

			case TBlock(exprs):
				var buf = new StringBuf();
				for (e in exprs) {
					buf.add(translateTypedExpr(e));
				}
				return buf.toString();

			case TCall(func, args):
				// Check for static factory calls: Text.withState(...)
				var staticResult = tryTranslateStaticCall(func, args);
				if (staticResult != null) return staticResult;

				// Check for view-returning function calls (instance + static methods)
				var inlined = tryInlineViewCall(func, args);
				if (inlined != null) return inlined;

				// Check for modifier chain: someView.modifier(args)
				switch (func.expr) {
					case TField(innerExpr, fa):
						var fieldName = getFieldName(fa);
						if (isModifierMethod(fieldName)) {
							var modifiers:Array<{name:String, args:Array<TypedExpr>}> = [];
							modifiers.push({name: fieldName, args: args});
							var baseExpr = unwrapModifierChain(innerExpr, modifiers);
							modifiers.reverse();

							// Check if base is a static call (e.g., Text.withState(...).bold())
							switch (baseExpr.expr) {
								case TCall(bFunc, bArgs):
									var staticBase = tryTranslateStaticCallWithMods(bFunc, bArgs, modifiers);
									if (staticBase != null) return staticBase;
								default:
							}

							switch (baseExpr.expr) {
								case TNew(classRef, _, ctorArgs):
									var cls = classRef.get();
									var fullName = resolveAuiClassName(cls);
									return translateViewWithModifiers(fullName, ctorArgs, modifiers);
								default:
									return translateTypedExpr(baseExpr);
							}
						}
						return translateTypedExpr(func);
					default:
						return translateTypedExpr(func);
				}

			case TConst(c):
				switch (c) {
					case TString(s): return '"${escapeString(s)}"';
					case TInt(i): return Std.string(i);
					case TFloat(f): return f;
					case TBool(b): return b ? "true" : "false";
					case TNull: return "null";
					default: return "";
				}

			case TLocal(v):
				// A lambda parameter bound by an enclosing ForEach is already in
				// Kotlin scope -- emit the identifier directly so
				// `new Text(item)` becomes `Text(text = "$item", …)`.
				if (_lambdaParamIds.exists(v.id)) {
					return _lambdaParamIds.get(v.id);
				}
				// Resolve local bindings from inlined function parameters
				if (_localBindings.exists(v.id)) {
					return translateTypedExpr(_localBindings.get(v.id));
				}
				return "";

			case TField(e, fa):
				return translateTypedExpr(e);

			default:
				return "";
		}
	}

	// Try to translate static method calls like Text.withState(...)
	static function tryTranslateStaticCall(func:TypedExpr, args:Array<TypedExpr>):Null<String> {
		switch (func.expr) {
			case TField(_, fa):
				var fieldName = getFieldName(fa);
				if (fieldName == "withState" && args.length > 0) {
					return translateTextWithState(args[0], []);
				}
			default:
		}
		return null;
	}

	static function tryTranslateStaticCallWithMods(func:TypedExpr, args:Array<TypedExpr>,
			modifiers:Array<{name:String, args:Array<TypedExpr>}>):Null<String> {
		switch (func.expr) {
			case TField(_, fa):
				var fieldName = getFieldName(fa);
				if (fieldName == "withState" && args.length > 0) {
					return translateTextWithState(args[0], modifiers);
				}
			default:
		}
		return null;
	}

	static function translateTextWithState(templateExpr:TypedExpr,
			modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var indent = getIndent();
		var template = "";

		switch (templateExpr.expr) {
			case TConst(TString(s)):
				template = s;
			default:
				template = translateTypedExpr(templateExpr);
		}

		// Convert {varName} → ${app.varName.get()} for Kotlin string interpolation,
		// reading from the Haxe-managed Compose-observable state.
		var reg = ~/\{([^}]+)\}/g;
		var kotlinStr = reg.map(template, function(r) {
			var ref = r.matched(1);
			// If `ref` matches a known state field, route through app; otherwise
			// keep the legacy `$ref` syntax (e.g. for plain captured locals).
			for (sf in _stateFields) {
				if (sf.name == ref) return "${" + stateReadForInterp(ref) + "}";
			}
			return "$" + ref;
		});

		var hasBold = false;
		var hasItalic = false;
		for (mod in modifiers) {
			if (mod.name == "bold") hasBold = true;
			if (mod.name == "italic") hasItalic = true;
		}
		var layoutMods = buildModifierChain(modifiers);

		var buf = new StringBuf();
		buf.add(indent + "Text(\n");
		buf.add(indent + '    text = "' + kotlinStr + '"');

		for (mod in modifiers) {
			if (mod.name == "foregroundColor" && mod.args.length > 0) {
				buf.add(",\n" + indent + "    color = " + translateColorArg(mod.args[0]));
			}
		}
		for (mod in modifiers) {
			if (mod.name == "font" && mod.args.length > 0) {
				var fontInfo = translateFontArg(mod.args[0]);
				if (fontInfo.style != null) {
					buf.add(",\n" + indent + "    style = " + fontInfo.style);
				}
			}
		}
		if (hasBold) buf.add(",\n" + indent + "    fontWeight = FontWeight.Bold");
		if (hasItalic) buf.add(",\n" + indent + "    fontStyle = FontStyle.Italic");
		if (layoutMods.length > 0) buf.add(",\n" + indent + "    modifier = " + layoutMods);

		buf.add("\n" + indent + ")\n");
		return buf.toString();
	}

	static function unwrapModifierChain(expr:TypedExpr, modifiers:Array<{name:String, args:Array<TypedExpr>}>):TypedExpr {
		switch (expr.expr) {
			case TCall(func, args):
				switch (func.expr) {
					case TField(innerExpr, fa):
						var fieldName = getFieldName(fa);
						if (isModifierMethod(fieldName)) {
							modifiers.push({name: fieldName, args: args});
							return unwrapModifierChain(innerExpr, modifiers);
						}
					default:
				}
			default:
		}
		return expr;
	}

	static function getFieldName(fa:FieldAccess):String {
		switch (fa) {
			case FInstance(_, _, cf): return cf.get().name;
			case FStatic(_, cf): return cf.get().name;
			case FAnon(cf): return cf.get().name;
			case FClosure(_, cf): return cf.get().name;
			case FDynamic(s): return s;
			case FEnum(_, ef): return ef.name;
		}
	}

	static function isModifierMethod(name:String):Bool {
		return [
			"padding", "paddingHorizontal", "paddingVertical",
			"frame", "fillMaxWidth", "fillMaxHeight", "fillMaxSize",
			"offset", "aspectRatio",
			"font", "bold", "italic", "lineLimit", "multilineTextAlignment",
			"foregroundColor", "background", "opacity", "cornerRadius",
			"clipShape", "shadow", "blur", "scaleEffect", "rotationEffect",
			"brightness", "contrast", "saturation", "grayscale",
			"border", "overlay",
			"onTapGesture", "onLongPressGesture", "onAppear", "onDisappear",
			"disabled", "hidden",
			"sheet", "alert", "navigationTitle", "animation",
			"accessibilityLabel", "accessibilityHint"
		].indexOf(name) != -1;
	}

	// -------------------------------------------------------------------------
	// View translation
	// -------------------------------------------------------------------------

	// Resolve a class to its canonical aui.* name by walking up the superclass chain.
	// Allows wrappers like mui.ui.VStack (extends aui.ui.VStack) to be matched as aui.ui.VStack.
	static function resolveAuiClassName(cls:ClassType):String {
		var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
		if (StringTools.startsWith(fullName, "aui.")) return fullName;
		var sc = cls.superClass;
		while (sc != null) {
			var scCls = sc.t.get();
			var scName = scCls.pack.join(".") + (scCls.pack.length > 0 ? "." : "") + scCls.name;
			if (StringTools.startsWith(scName, "aui.")) return scName;
			sc = scCls.superClass;
		}
		return fullName;
	}

	static function translateViewWithModifiers(fullName:String, args:Array<TypedExpr>,
			modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var indent = getIndent();
		var modStr = buildModifierChain(modifiers);

		// Handle presentation modifiers (sheet, alert) as wrappers
		var prefix = "";
		var suffix = "";
		for (mod in modifiers) {
			if (mod.name == "sheet" && mod.args.length >= 2) {
				var stateName = extractStateFieldName(mod.args[0]);
				if (stateName != null) {
					prefix += indent + "if (" + stateRead(stateName) + ") {\n";
					prefix += indent + "    ModalBottomSheet(onDismissRequest = { " + stateAssign(stateName, "false") + " }) {\n";
					_indent += 2;
					prefix += translateTypedExpr(mod.args[1]);
					_indent -= 2;
					prefix += indent + "    }\n";
					prefix += indent + "}\n";
				}
			}
			if (mod.name == "alert" && mod.args.length >= 2) {
				var title = translateTypedExpr(mod.args[0]);
				var stateName = extractStateFieldName(mod.args[1]);
				var message = mod.args.length >= 3 ? translateTypedExpr(mod.args[2]) : "null";
				if (stateName != null) {
					prefix += indent + "if (" + stateRead(stateName) + ") {\n";
					prefix += indent + "    AlertDialog(\n";
					prefix += indent + "        onDismissRequest = { " + stateAssign(stateName, "false") + " },\n";
					prefix += indent + "        title = { Text(" + title + ") },\n";
					if (message != "null") {
						prefix += indent + "        text = { Text(" + message + ") },\n";
					}
					prefix += indent + '        confirmButton = { TextButton(onClick = { ' + stateAssign(stateName, "false")
						+ ' }) { Text("OK") } }\n';
					prefix += indent + "    )\n";
					prefix += indent + "}\n";
				}
			}
		}

		var viewCode = "";
		switch (fullName) {
			case "aui.ui.Text":
				viewCode = generateText(args, modifiers, indent);
			case "aui.ui.VStack":
				viewCode = generateContainer("Column", args, modStr, indent);
			case "aui.ui.HStack":
				viewCode = generateContainer("Row", args, modStr, indent);
			case "aui.ui.ZStack":
				viewCode = generateContainer("Box", args, modStr, indent);
			case "aui.ui.Spacer":
				viewCode = modStr.length > 0 ? indent + "Spacer(modifier = " + modStr + ")\n"
					: indent + "Spacer(modifier = Modifier.weight(1f))\n";
			case "aui.ui.Button":
				viewCode = generateButton(args, modStr, indent);
			case "aui.ui.Divider":
				viewCode = modStr.length > 0 ? indent + "HorizontalDivider(modifier = " + modStr + ")\n"
					: indent + "HorizontalDivider()\n";
			case "aui.ui.TextField":
				viewCode = generateTextField(args, modStr, indent);
			case "aui.ui.Toggle":
				viewCode = generateToggle(args, modStr, indent);
			case "aui.ui.Slider":
				viewCode = generateSlider(args, modStr, indent);
			case "aui.ui.ScrollView":
				viewCode = generateScrollView(args, modStr, indent);
			case "aui.ui.Image":
				viewCode = generateImage(args, modStr, indent);
			case "aui.ui.ConditionalView":
				viewCode = generateConditionalView(args, indent);
			case "aui.ui.NavigationStack":
				viewCode = generateNavigationStack(args, modStr, indent);
			case "aui.ui.NavigationLink":
				viewCode = generateNavigationLink(args, modStr, indent);
			case "aui.ui.TabView":
				viewCode = generateTabView(args, modStr, indent);
			case "aui.ui.ForEach":
				viewCode = generateForEach(args, indent);
			case "aui.ui.Section":
				viewCode = generateSection(args, modStr, indent);
			case "aui.ui.LazyColumn":
				viewCode = generateLazyColumn(args, modStr, indent);
			case "aui.ui.ProgressView":
				viewCode = generateProgressView(args, modStr, indent);
			case "aui.ui.Card":
				viewCode = generateCard(args, modStr, indent);
			case "aui.ui.SafeArea" | "mui.ui.SafeArea":
				var safeMod = modStr.length > 0
					? 'Modifier.safeDrawingPadding().then($modStr)'
					: "Modifier.safeDrawingPadding()";
				viewCode = generateContainer("Column", args, safeMod, indent);
			default:
				// A view this generator cannot emit disappears from the screen,
				// and a comment in a generated file is not a report. Say it where
				// the developer can act on it.
				//
				// A ViewComponent gets its own message: it is not an unknown type
				// but an unsupported *shape* -- the static path would have to emit
				// a separate composable carrying the component's own state, which
				// it does not do. The dynamic renderer expands it and works today.
				if (StringTools.endsWith(fullName, "ViewComponent") || isComponentName(fullName)) {
					Context.error('The static path cannot render a ViewComponent ("' + fullName + '").\n'
						+ '  It would need a composable of its own, carrying the component\'s state.\n'
						+ '  Drop -D ' + RenderPath.STATIC_DEFINE + ' -- the dynamic renderer, which is\n'
						+ '  the default, expands components.',
						Context.currentPos());
				}
				Context.error('The static path cannot render "' + fullName + '".\n'
					+ '  Only aui\'s own view types are emitted to Kotlin here.\n'
					+ '  Drop -D ' + RenderPath.STATIC_DEFINE + ', or compose from types aui provides.',
					Context.currentPos());
				viewCode = "";
		}
		return prefix + viewCode;
	}

	static function generateText(args:Array<TypedExpr>, modifiers:Array<{name:String, args:Array<TypedExpr>}>,
			indent:String):String {
		var textContent = '""';
		if (args.length > 0) textContent = translateTypedExpr(args[0]);

		var hasBold = false;
		var hasItalic = false;
		for (mod in modifiers) {
			if (mod.name == "bold") hasBold = true;
			if (mod.name == "italic") hasItalic = true;
		}
		var layoutMods = buildModifierChain(modifiers);

		var buf = new StringBuf();
		buf.add(indent + "Text(\n");
		buf.add(indent + "    text = " + textContent);

		for (mod in modifiers) {
			if (mod.name == "foregroundColor" && mod.args.length > 0) {
				buf.add(",\n" + indent + "    color = " + translateColorArg(mod.args[0]));
			}
		}
		for (mod in modifiers) {
			if (mod.name == "font" && mod.args.length > 0) {
				var fontInfo = translateFontArg(mod.args[0]);
				if (fontInfo.style != null) buf.add(",\n" + indent + "    style = " + fontInfo.style);
			}
		}
		if (hasBold) buf.add(",\n" + indent + "    fontWeight = FontWeight.Bold");
		if (hasItalic) buf.add(",\n" + indent + "    fontStyle = FontStyle.Italic");
		for (mod in modifiers) {
			if (mod.name == "multilineTextAlignment" && mod.args.length > 0)
				buf.add(",\n" + indent + "    textAlign = " + translateTextAlignArg(mod.args[0]));
		}
		if (layoutMods.length > 0) buf.add(",\n" + indent + "    modifier = " + layoutMods);

		buf.add("\n" + indent + ")\n");
		return buf.toString();
	}

	static function generateContainer(composeName:String, args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		var contentArg:Null<TypedExpr> = null;
		var spacingArg:Null<TypedExpr> = null;
		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(_): contentArg = arg;
				case TConst(TInt(_)), TConst(TFloat(_)): spacingArg = arg;
				default:
			}
		}

		var params = new Array<String>();
		if (modStr.length > 0) params.push("modifier = " + modStr);
		if (composeName == "Column") {
			params.push("horizontalAlignment = Alignment.CenterHorizontally");
		} else if (composeName == "Row") {
			params.push("verticalAlignment = Alignment.CenterVertically");
			if (spacingArg != null) {
				params.push("horizontalArrangement = Arrangement.spacedBy(" + translateTypedExpr(spacingArg) + ".dp)");
			}
		}

		if (params.length > 0) {
			buf.add(indent + composeName + "(\n");
			for (i in 0...params.length) {
				buf.add(indent + "    " + params[i]);
				if (i < params.length - 1) buf.add(",");
				buf.add("\n");
			}
			buf.add(indent + ") {\n");
		} else {
			buf.add(indent + composeName + " {\n");
		}

		if (contentArg != null) {
			switch (contentArg.expr) {
				case TArrayDecl(elements):
					_indent++;
					for (element in elements) buf.add(translateTypedExpr(element));
					_indent--;
				default:
			}
		}

		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateButton(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var label = '""';
		if (args.length > 0) label = translateTypedExpr(args[0]);

		// Action resolution order:
		// 1. StateAction enum (count.inc(), count.dec(), etc.) — direct AST translation
		// 2. Lifted-closure method reference (this.__aui_action_N) — call `app.<m>()`
		// Falls back to a no-op `{ }` only if both fail.
		var actionCode = "{ }";
		if (args.length >= 2) {
			var sa = translateStateAction(args[1]);
			if (sa != null) {
				actionCode = "{ " + sa + " }";
			} else {
				var mref = translateMethodRef(args[1]);
				if (mref != null) actionCode = "{ " + mref + " }";
			}
		}

		buf.add(indent + "Button(\n");
		buf.add(indent + "    onClick = " + actionCode);
		if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
		buf.add("\n" + indent + ") {\n");
		buf.add(indent + "    Text(" + label + ")\n");
		buf.add(indent + "}\n");
		return buf.toString();
	}

	// Recognise a method reference of the form `this.<name>` (typed as TField on
	// `this` or unwrapped through the inlined-binding layer). Used to detect
	// the lifted closures produced by aui.macros.StateMacro for button actions.
	// Returns the Kotlin call site `app.<name>()` or null if the expr isn't a
	// method reference.
	static function translateMethodRef(expr:TypedExpr):Null<String> {
		if (expr == null) return null;
		switch (expr.expr) {
			case TField(_, fa):
				switch (fa) {
					case FInstance(_, _, ref):
						var f = ref.get();
						switch (f.type) {
							case TFun(_, _):
								return "app." + f.name + "()";
							default:
						}
					case FClosure(_, ref):
						var f = ref.get();
						switch (f.type) {
							case TFun(_, _):
								return "app." + f.name + "()";
							default:
						}
					default:
				}
			case TParenthesis(e): return translateMethodRef(e);
			case TMeta(_, e): return translateMethodRef(e);
			case TCast(e, _): return translateMethodRef(e);
			default:
		}
		return null;
	}

	static function generateTextField(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		var placeholder = '""';
		if (args.length > 0) placeholder = translateTypedExpr(args[0]);

		// Second arg is the State<String> binding
		var stateName:Null<String> = null;
		if (args.length >= 2) stateName = extractStateFieldName(args[1]);

		if (stateName != null) {
			buf.add(indent + "OutlinedTextField(\n");
			buf.add(indent + "    value = " + stateRead(stateName) + ",\n");
			buf.add(indent + "    onValueChange = { " + stateAssign(stateName, "it") + " },\n");
			buf.add(indent + "    label = { Text(" + placeholder + ") }");
			if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
			else buf.add(",\n" + indent + "    modifier = Modifier.fillMaxWidth()");
			buf.add("\n" + indent + ")\n");
		} else {
			buf.add(indent + "OutlinedTextField(\n");
			buf.add(indent + '    value = "",\n');
			buf.add(indent + "    onValueChange = { },\n");
			buf.add(indent + "    label = { Text(" + placeholder + ") }");
			if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
			buf.add("\n" + indent + ")\n");
		}

		return buf.toString();
	}

	static function generateToggle(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		var label = '""';
		if (args.length > 0) label = translateTypedExpr(args[0]);

		var stateName:Null<String> = null;
		if (args.length >= 2) stateName = extractStateFieldName(args[1]);

		buf.add(indent + "Row(\n");
		buf.add(indent + "    verticalAlignment = Alignment.CenterVertically");
		if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
		else buf.add(",\n" + indent + "    modifier = Modifier.fillMaxWidth()");
		buf.add("\n" + indent + ") {\n");
		buf.add(indent + "    Text(text = " + label + ", modifier = Modifier.weight(1f))\n");
		if (stateName != null) {
			buf.add(indent + "    Switch(checked = " + stateRead(stateName) + ", onCheckedChange = { " + stateAssign(stateName, "it") + " })\n");
		} else {
			buf.add(indent + "    Switch(checked = false, onCheckedChange = { })\n");
		}
		buf.add(indent + "}\n");

		return buf.toString();
	}

	static function generateSlider(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var indent2 = indent;
		var buf = new StringBuf();

		var stateName:Null<String> = null;
		if (args.length >= 1) stateName = extractStateFieldName(args[0]);

		var mod = modStr.length > 0 ? modStr : "Modifier.fillMaxWidth()";
		if (stateName != null) {
			buf.add(indent + "Slider(\n");
			buf.add(indent + "    value = " + stateRead(stateName) + ".toFloat(),\n");
			buf.add(indent + "    onValueChange = { " + stateAssign(stateName, "it") + " },\n");
			buf.add(indent + "    modifier = " + mod + "\n");
			buf.add(indent + ")\n");
		} else {
			buf.add(indent + "Slider(\n");
			buf.add(indent + "    value = 0f,\n");
			buf.add(indent + "    onValueChange = { },\n");
			buf.add(indent + "    modifier = " + mod + "\n");
			buf.add(indent + ")\n");
		}

		return buf.toString();
	}

	static function generateScrollView(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var mod = modStr.length > 0 ? modStr + ".verticalScroll(rememberScrollState())"
			: "Modifier.fillMaxSize().verticalScroll(rememberScrollState())";

		buf.add(indent + "Column(\n");
		buf.add(indent + "    modifier = " + mod + "\n");
		buf.add(indent + ") {\n");

		// Children are in the first array arg
		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(elements):
					_indent++;
					for (element in elements) buf.add(translateTypedExpr(element));
					_indent--;
				default:
			}
		}

		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateImage(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var name = '""';
		if (args.length > 0) name = translateTypedExpr(args[0]);

		var buf = new StringBuf();
		buf.add(indent + "// Image: " + name + "\n");
		buf.add(indent + "Icon(\n");
		buf.add(indent + "    imageVector = Icons.Default.Star,\n");
		buf.add(indent + '    contentDescription = ' + name);
		if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
		buf.add("\n" + indent + ")\n");
		return buf.toString();
	}

	static function generateConditionalView(args:Array<TypedExpr>, indent:String):String {
		var buf = new StringBuf();

		var stateName:Null<String> = null;
		if (args.length >= 1) stateName = extractStateFieldName(args[0]);
		var condVar = stateName != null ? stateRead(stateName) : "false";

		buf.add(indent + "if (" + condVar + ") {\n");
		if (args.length >= 2) {
			_indent++;
			buf.add(translateTypedExpr(args[1]));
			_indent--;
		}
		buf.add(indent + "}");

		if (args.length >= 3) {
			buf.add(" else {\n");
			_indent++;
			buf.add(translateTypedExpr(args[2]));
			_indent--;
			buf.add(indent + "}");
		}
		buf.add("\n");

		return buf.toString();
	}

	// -------------------------------------------------------------------------
	// Navigation & list views
	// -------------------------------------------------------------------------

	static function generateNavigationStack(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		buf.add(indent + "NavHost(\n");
		buf.add(indent + '    navController = navController,\n');
		buf.add(indent + '    startDestination = "home"');
		if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
		buf.add("\n" + indent + ") {\n");

		// Home route contains the root content
		buf.add(indent + '    composable("home") {\n');
		if (args.length > 0) {
			_indent += 2;
			buf.add(translateTypedExpr(args[0]));
			_indent -= 2;
		}
		buf.add(indent + "    }\n");

		// Additional routes from NavigationLinks
		for (route in _navRoutes) {
			buf.add(indent + '    composable("' + route.id + '") {\n');
			_indent += 2;
			buf.add(translateTypedExpr(route.bodyExpr));
			_indent -= 2;
			buf.add(indent + "    }\n");
		}

		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateNavigationLink(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var label = '""';
		if (args.length > 0) label = translateTypedExpr(args[0]);

		// Find the route ID for this NavigationLink
		var routeId = "home";
		if (args.length >= 2) {
			for (route in _navRoutes) {
				// Match by expression identity (same position in source)
				if (route.bodyExpr == args[1]) {
					routeId = route.id;
					break;
				}
			}
		}

		buf.add(indent + "Button(\n");
		buf.add(indent + '    onClick = { navController.navigate("' + routeId + '") }');
		if (modStr.length > 0) buf.add(",\n" + indent + "    modifier = " + modStr);
		buf.add("\n" + indent + ") {\n");
		buf.add(indent + "    Text(" + label + ")\n");
		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateTabView(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		// Collect Tab constructors from the array arg
		var tabs:Array<{title:String, icon:String, bodyExpr:TypedExpr}> = [];
		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(elements):
					for (el in elements) {
						switch (el.expr) {
							case TNew(classRef, _, tabArgs):
								var cls = classRef.get();
								var name = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
								if (name == "aui.ui.Tab" && tabArgs.length >= 3) {
									tabs.push({
										title: translateTypedExpr(tabArgs[0]),
										icon: extractStringValue(tabArgs[1]),
										bodyExpr: tabArgs[2]
									});
								}
							default:
						}
					}
				default:
			}
		}

		if (tabs.length == 0) return indent + "// Empty TabView\n";

		buf.add(indent + "var selectedTab by remember { mutableStateOf(0) }\n\n");
		buf.add(indent + "Scaffold(\n");
		buf.add(indent + "    bottomBar = {\n");
		buf.add(indent + "        NavigationBar {\n");
		for (i in 0...tabs.length) {
			var tab = tabs[i];
			var iconName = mapIconName(tab.icon);
			buf.add(indent + "            NavigationBarItem(\n");
			buf.add(indent + "                selected = selectedTab == " + i + ",\n");
			buf.add(indent + "                onClick = { selectedTab = " + i + " },\n");
			buf.add(indent + "                icon = { Icon(Icons.Filled." + iconName + ', contentDescription = ' + tab.title + ") },\n");
			buf.add(indent + "                label = { Text(" + tab.title + ") }\n");
			buf.add(indent + "            )\n");
		}
		buf.add(indent + "        }\n");
		buf.add(indent + "    }\n");
		buf.add(indent + ") { innerPadding ->\n");
		buf.add(indent + "    when (selectedTab) {\n");
		for (i in 0...tabs.length) {
			buf.add(indent + "        " + i + " -> {\n");
			_indent += 3;
			var savedIndent = _indent;
			buf.add(indent + "            Column(modifier = Modifier.padding(innerPadding)) {\n");
			_indent += 4;
			buf.add(translateTypedExpr(tabs[i].bodyExpr));
			_indent = savedIndent;
			buf.add(indent + "            }\n");
			_indent -= 3;
			buf.add(indent + "        }\n");
		}
		buf.add(indent + "    }\n");
		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateForEach(args:Array<TypedExpr>, indent:String):String {
		var buf = new StringBuf();

		if (args.length < 2) return indent + "// ForEach: missing arguments\n";

		// First arg: the state/collection to iterate
		var stateName = extractStateFieldName(args[0]);
		var collectionExpr = stateName != null ? stateRead(stateName) : "emptyList<Any>()";

		// Second arg: the builder function
		var paramName = "item";
		var paramId:Int = -1;
		var builderBody:Null<TypedExpr> = null;

		switch (args[1].expr) {
			case TFunction(tf):
				if (tf.args.length > 0) {
					paramName = tf.args[0].v.name;
					paramId = tf.args[0].v.id;
				}
				builderBody = tf.expr;
			default:
		}

		buf.add(indent + collectionExpr + ".forEachIndexed { index, " + paramName + " ->\n");
		if (builderBody != null) {
			// Register the lambda parameter so TLocal references inside the body
			// resolve to the Kotlin identifier. Saved and restored, so a nested
			// ForEach does not leak its parameter to the enclosing one.
			var savedLambdaParams = _lambdaParamIds.copy();
			if (paramId >= 0) _lambdaParamIds.set(paramId, paramName);
			_indent++;
			buf.add(translateTypedExpr(builderBody));
			_indent--;
			_lambdaParamIds = savedLambdaParams;
		}
		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateSection(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		// Find header (string arg) and content (array arg)
		var header:Null<String> = null;
		var contentArg:Null<TypedExpr> = null;
		for (arg in args) {
			switch (arg.expr) {
				case TConst(TString(s)): header = s;
				case TArrayDecl(_): contentArg = arg;
				default:
			}
		}

		if (header != null) {
			buf.add(indent + "Text(\n");
			buf.add(indent + '    text = "' + escapeString(header) + '",\n');
			buf.add(indent + "    style = MaterialTheme.typography.titleMedium,\n");
			buf.add(indent + "    color = MaterialTheme.colorScheme.primary,\n");
			buf.add(indent + "    modifier = Modifier.padding(vertical = 8.dp)\n");
			buf.add(indent + ")\n");
		}

		if (contentArg != null) {
			switch (contentArg.expr) {
				case TArrayDecl(elements):
					for (element in elements) {
						buf.add(translateTypedExpr(element));
					}
				default:
			}
		}

		if (header != null) {
			buf.add(indent + "HorizontalDivider(modifier = Modifier.padding(vertical = 4.dp))\n");
		}

		return buf.toString();
	}

	static function generateLazyColumn(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var mod = modStr.length > 0 ? modStr : "Modifier.fillMaxSize()";

		buf.add(indent + "LazyColumn(\n");
		buf.add(indent + "    modifier = " + mod + "\n");
		buf.add(indent + ") {\n");

		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(elements):
					for (element in elements) {
						buf.add(indent + "    item {\n");
						_indent += 2;
						buf.add(translateTypedExpr(element));
						_indent -= 2;
						buf.add(indent + "    }\n");
					}
				default:
			}
		}

		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function generateProgressView(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var stateName:Null<String> = null;
		if (args.length >= 1) stateName = extractStateFieldName(args[0]);

		var mod = modStr.length > 0 ? modStr : "Modifier";
		if (stateName != null) {
			return indent + "LinearProgressIndicator(\n" + indent + "    progress = { " + stateRead(stateName) + ".toFloat() },\n" + indent
				+ "    modifier = " + mod + ".fillMaxWidth()\n" + indent + ")\n";
		}
		return indent + "CircularProgressIndicator(" + (modStr.length > 0 ? "modifier = " + modStr : "") + ")\n";
	}

	static function generateCard(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var mod = modStr.length > 0 ? modStr + ".fillMaxWidth()" : "Modifier.fillMaxWidth()";

		buf.add(indent + "Card(\n");
		buf.add(indent + "    modifier = " + mod + "\n");
		buf.add(indent + ") {\n");

		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(elements):
					_indent++;
					for (element in elements) buf.add(translateTypedExpr(element));
					_indent--;
				default:
			}
		}

		buf.add(indent + "}\n");
		return buf.toString();
	}

	static function extractStringValue(expr:TypedExpr):String {
		switch (expr.expr) {
			case TConst(TString(s)): return s;
			default: return "";
		}
	}

	static function mapIconName(icon:String):String {
		switch (icon) {
			case "house", "home": return "Home";
			case "gear", "settings": return "Settings";
			case "person", "profile": return "Person";
			case "star", "favorite": return "Star";
			case "search": return "Search";
			case "list": return "List";
			case "info": return "Info";
			case "add", "plus": return "Add";
			case "edit": return "Edit";
			case "delete", "trash": return "Delete";
			case "email", "mail": return "Email";
			case "phone", "call": return "Phone";
			default: return "Star";
		}
	}

	// -------------------------------------------------------------------------
	// StateAction translation
	// -------------------------------------------------------------------------

	// Translates a StateAction expression to Kotlin code (without braces)
	// e.g. count.inc() → "count++"
	static function translateStateAction(expr:TypedExpr):Null<String> {
		switch (expr.expr) {
			case TCall(func, args):
				switch (func.expr) {
					case TField(receiver, fa):
						var methodName = getFieldName(fa);
						var stateName = extractStateFieldName(receiver);
						if (stateName == null) return null;

						// State now lives on the App instance (app.<name>), backed by
						// a Compose MutableState, so mutations go through the
						// get/set bridge rather than a Kotlin local. stateRead() is
						// the typed read, so arithmetic/logical ops apply correctly.
						switch (methodName) {
							case "inc":
								var amount = args.length > 0 ? translateTypedExpr(args[0]) : "";
								if (amount == "null" || amount == "") amount = "1";
								return stateAssign(stateName, stateRead(stateName) + " + " + amount);
							case "dec":
								var amount = args.length > 0 ? translateTypedExpr(args[0]) : "";
								if (amount == "null" || amount == "") amount = "1";
								return stateAssign(stateName, stateRead(stateName) + " - " + amount);
							case "setTo":
								if (args.length > 0) {
									var value = translateTypedExpr(args[0]);
									return stateAssign(stateName, value);
								}
								return null;
							case "tog":
								return stateAssign(stateName, "!" + stateRead(stateName));
							case "appendAction":
								if (args.length > 0) {
									var value = translateTypedExpr(args[0]);
									return stateAssign(stateName, stateRead(stateName) + " + " + value);
								}
								return null;
							default:
								return null;
						}
					default:
				}
			default:
		}
		return null;
	}

	// Extract the name of a State field from a typed expression
	// Handles: this.fieldName, fieldName (local), and abstract @:from / unwrap calls
	// (e.g. TextInputBinding.fromState(state).unwrap() should resolve to "state")
	static function extractStateFieldName(expr:TypedExpr):Null<String> {
		if (expr == null) return null;
		switch (expr.expr) {
			case TField(_, fa):
				var name = getFieldName(fa);
				for (sf in _stateFields) {
					if (sf.name == name) return name;
				}
				return null;
			case TLocal(v):
				if (_localBindings.exists(v.id)) {
					return extractStateFieldName(_localBindings.get(v.id));
				}
				for (sf in _stateFields) {
					if (sf.name == v.name) return v.name;
				}
				return null;
			case TCall(_, args):
				// @:from / unwrap / wrap helpers: dig into the args
				for (a in args) {
					var n = extractStateFieldName(a);
					if (n != null) return n;
				}
				return null;
			case TCast(e, _):
				return extractStateFieldName(e);
			case TParenthesis(e):
				return extractStateFieldName(e);
			case TMeta(_, e):
				return extractStateFieldName(e);
			default:
				return null;
		}
	}

	// -------------------------------------------------------------------------
	// Modifier translation
	// -------------------------------------------------------------------------

	static function buildModifierChain(modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var parts = new Array<String>();
		for (mod in modifiers) {
			var part = translateSingleModifier(mod.name, mod.args);
			if (part.length > 0) parts.push(part);
		}
		if (parts.length == 0) return "";
		return "Modifier" + parts.join("");
	}

	static function translateSingleModifier(name:String, args:Array<TypedExpr>):String {
		switch (name) {
			case "padding":
				if (args.length > 0) {
					var value = translateTypedExpr(args[0]);
					if (value == "null" || value == "") return ".padding(16.dp)";
					return ".padding(" + value + ".dp)";
				}
				return ".padding(16.dp)";
			case "background":
				if (args.length > 0) return ".background(" + translateColorArg(args[0]) + ")";
				return "";
			case "cornerRadius":
				if (args.length > 0) return ".clip(RoundedCornerShape(" + translateTypedExpr(args[0]) + ".dp))";
				return "";
			case "opacity":
				if (args.length > 0) return ".alpha(" + translateTypedExpr(args[0]) + "f)";
				return "";
			case "frame":
				var parts = new Array<String>();
				if (args.length > 0) parts.push("width = " + translateTypedExpr(args[0]) + ".dp");
				if (args.length > 1) parts.push("height = " + translateTypedExpr(args[1]) + ".dp");
				if (parts.length > 0) return ".size(" + parts.join(", ") + ")";
				return "";
			case "offset":
				if (args.length >= 2)
					return ".offset(x = " + translateTypedExpr(args[0]) + ".dp, y = " + translateTypedExpr(args[1]) + ".dp)";
				return "";
			case "blur":
				if (args.length > 0) return ".blur(" + translateTypedExpr(args[0]) + ".dp)";
				return "";
			case "scaleEffect":
				if (args.length > 0) return ".scale(" + translateTypedExpr(args[0]) + "f)";
				return "";
			case "rotationEffect":
				if (args.length > 0) return ".rotate(" + translateTypedExpr(args[0]) + "f)";
				return "";
			case "hidden":
				return ".alpha(0f)";
			case "disabled":
				return "";
			case "shadow":
				return ".shadow(elevation = 4.dp)";
			case "border":
				if (args.length > 0) {
					var color = translateColorArg(args[0]);
					var width = args.length > 1 ? translateTypedExpr(args[1]) : "1";
					return ".border(" + width + ".dp, " + color + ")";
				}
				return "";
			case "fillMaxWidth":
				return ".fillMaxWidth()";
			case "fillMaxHeight":
				return ".fillMaxHeight()";
			case "fillMaxSize":
				return ".fillMaxSize()";
			case "paddingHorizontal":
				if (args.length > 0) return ".padding(horizontal = " + translateTypedExpr(args[0]) + ".dp)";
				return "";
			case "paddingVertical":
				if (args.length > 0) return ".padding(vertical = " + translateTypedExpr(args[0]) + ".dp)";
				return "";
			case "aspectRatio":
				if (args.length > 0) {
					var ratio = translateTypedExpr(args[0]);
					if (ratio == "null") return ".aspectRatio(1f)";
					return ".aspectRatio(" + ratio + "f)";
				}
				return ".aspectRatio(1f)";
			case "clipShape":
				// Shape arg is an enum — need to check what shape
				return ".clip(RoundedCornerShape(8.dp))";
			case "brightness":
				return ""; // Compose handles via ColorMatrix — skip for now
			case "contrast":
				return "";
			case "saturation":
				return "";
			case "grayscale":
				return "";
			case "onTapGesture":
				return ".clickable { }";
			case "onLongPressGesture":
				return "";
			case "onAppear":
				return ""; // Handled separately via LaunchedEffect
			case "onDisappear":
				return "";
			case "animation":
				return ".animateContentSize()";
			case "font", "bold", "italic", "foregroundColor", "lineLimit", "multilineTextAlignment":
				return ""; // Handled in generateText
			case "sheet", "alert":
				return ""; // Handled as wrapper, not modifier chain
			case "navigationTitle":
				return ""; // Handled at Scaffold level
			case "accessibilityLabel":
				return ""; // Handled via semantics
			case "accessibilityHint":
				return "";
			default:
				return "/* " + name + " */";
		}
	}

	static function extractTextParams(modifiers:Array<{name:String, args:Array<TypedExpr>}>):Map<String, String> {
		var params = new Map<String, String>();
		for (mod in modifiers) {
			switch (mod.name) {
				case "bold":
					params.set("fontWeight", "FontWeight.Bold");
				case "italic":
					params.set("fontStyle", "FontStyle.Italic");
				default:
			}
		}
		return params;
	}

	// -------------------------------------------------------------------------
	// Argument translators
	// -------------------------------------------------------------------------

	static function translateColorArg(expr:TypedExpr):String {
		switch (expr.expr) {
			case TField(_, fa):
				switch (getFieldName(fa)) {
					case "Red": return "Color.Red";
					case "Blue": return "Color.Blue";
					case "Green": return "Color.Green";
					case "Yellow": return "Color.Yellow";
					case "Black": return "Color.Black";
					case "White": return "Color.White";
					case "Gray": return "Color.Gray";
					case "Purple": return "Color(0xFF9C27B0)";
					case "Pink": return "Color(0xFFE91E63)";
					case "Orange": return "Color(0xFFFF9800)";
					case "Transparent": return "Color.Transparent";
					case "Primary": return "MaterialTheme.colorScheme.primary";
					case "Secondary": return "MaterialTheme.colorScheme.secondary";
					default: return "Color.Unspecified";
				}
			default:
				return "Color.Unspecified";
		}
	}

	static function translateFontArg(expr:TypedExpr):{fontSize:Null<String>, style:Null<String>} {
		switch (expr.expr) {
			case TField(_, fa):
				switch (getFieldName(fa)) {
					case "DisplayLarge": return {fontSize: "57.sp", style: "MaterialTheme.typography.displayLarge"};
					case "DisplayMedium": return {fontSize: "45.sp", style: "MaterialTheme.typography.displayMedium"};
					case "DisplaySmall": return {fontSize: "36.sp", style: "MaterialTheme.typography.displaySmall"};
					case "HeadlineLarge": return {fontSize: "32.sp", style: "MaterialTheme.typography.headlineLarge"};
					case "HeadlineMedium": return {fontSize: "28.sp", style: "MaterialTheme.typography.headlineMedium"};
					case "HeadlineSmall": return {fontSize: "24.sp", style: "MaterialTheme.typography.headlineSmall"};
					case "TitleLarge": return {fontSize: "22.sp", style: "MaterialTheme.typography.titleLarge"};
					case "TitleMedium": return {fontSize: "16.sp", style: "MaterialTheme.typography.titleMedium"};
					case "TitleSmall": return {fontSize: "14.sp", style: "MaterialTheme.typography.titleSmall"};
					case "BodyLarge": return {fontSize: "16.sp", style: "MaterialTheme.typography.bodyLarge"};
					case "BodyMedium": return {fontSize: "14.sp", style: "MaterialTheme.typography.bodyMedium"};
					case "BodySmall": return {fontSize: "12.sp", style: "MaterialTheme.typography.bodySmall"};
					case "LabelLarge": return {fontSize: "14.sp", style: "MaterialTheme.typography.labelLarge"};
					case "LabelMedium": return {fontSize: "12.sp", style: "MaterialTheme.typography.labelMedium"};
					case "LabelSmall": return {fontSize: "11.sp", style: "MaterialTheme.typography.labelSmall"};
					default: return {fontSize: null, style: null};
				}
			default:
				return {fontSize: null, style: null};
		}
	}

	static function translateTextAlignArg(expr:TypedExpr):String {
		switch (expr.expr) {
			case TField(_, fa):
				switch (getFieldName(fa)) {
					case "Start": return "TextAlign.Start";
					case "Center": return "TextAlign.Center";
					case "End": return "TextAlign.End";
					default: return "TextAlign.Start";
				}
			default:
				return "TextAlign.Start";
		}
	}

	// -------------------------------------------------------------------------
	// AUI runtime Kotlin helpers
	// -------------------------------------------------------------------------

	// Emit the small Kotlin runtime that the Haxe state classes call into.
	// Currently just StateBridge — wraps Compose's mutableStateOf so Haxe's
	// State<T> can be a Compose-observable cell without depending on Compose
	// types from the Haxe side.
	//
	// The content is sourced from the file at `runtime/StateBridge.kt` in the
	// aui haxelib (resolved via Context.resolvePath against the State.hx path
	// that the Haxe compiler is already loading). This keeps a single source
	// of truth — change StateBridge.kt and the next build picks it up.
	static function writeAuiRuntimeKotlin():Void {
		// State bridge (always emitted — every aui app uses State<T>)
		var stateDir = "android/app/src/main/kotlin/aui/state";
		ensureDir(stateDir);
		var stateBridge = locateAuiRuntimeFile("StateBridge.kt");
		if (stateBridge != null) {
			copyIfNewer(stateBridge, stateDir + "/StateBridge.kt");
		} else {
			Context.warning('[AUI] StateBridge.kt not found in aui/runtime/ — state bridge will be missing', Context.currentPos());
		}

		// The dynamic renderer. It is Kotlin in package `aui.runtime` -- the same
		// package as the Haxe ViewNodeBridge it calls, so the class loader pairs
		// them with no import and no JNI.
		var runtimeDir = "android/app/src/main/kotlin/aui/runtime";
		var rendererOut = runtimeDir + "/DynamicComposable.kt";

		if (RenderPath.isDynamic()) {
			ensureDir(runtimeDir);
			var renderer = locateAuiRuntimeFile("DynamicComposable.kt");
			if (renderer != null) {
				copyIfNewer(renderer, rendererOut);
			} else {
				Context.warning('[AUI] DynamicComposable.kt not found in aui/runtime/ — the app will not link', Context.currentPos());
			}
		} else if (FileSystem.exists(rendererOut)) {
			// Left over from a dynamic build. The Haxe half it calls
			// (aui.runtime.ViewNodeBridge) is only pulled into the jar on the
			// dynamic path, so leaving this file behind breaks the *static*
			// build with "Unresolved reference: ViewNodeBridge" -- a failure in
			// a mode the developer did not even ask for.
			FileSystem.deleteFile(rendererOut);
		}

		// Android IO helpers (assets + symlinks). Always emitted: cheap, and
		// most non-trivial apps end up needing one or the other.
		var androidDir = "android/app/src/main/kotlin/aui/android";
		ensureDir(androidDir);
		var androidIo = locateAuiRuntimeFile("AndroidIo.kt");
		if (androidIo != null) {
			copyIfNewer(androidIo, androidDir + "/AndroidIo.kt");
		}
	}

	// Resolve the absolute path of a runtime file shipped by the aui haxelib,
	// e.g. "StateBridge.kt" → "/path/to/aui/runtime/StateBridge.kt". Uses
	// Context.resolvePath on a known Haxe source file to anchor the lookup.
	static function locateAuiRuntimeFile(name:String):Null<String> {
		try {
			// Absolute, or walking up four levels from a relative classpath
			// (`-cp src`) runs out of path and lands on "/runtime/..." -- which
			// simply does not exist, so the runtime looked absent.
			var anchor = FileSystem.absolutePath(Context.resolvePath("aui/state/State.hx"));
			// Walk up: src/aui/state/State.hx → src/aui/state → src/aui → src → aui-root
			var dir = haxe.io.Path.directory(anchor); // .../aui/state
			dir = haxe.io.Path.directory(dir); // .../aui
			dir = haxe.io.Path.directory(dir); // .../src
			dir = haxe.io.Path.directory(dir); // .../<aui-root>
			var candidate = dir + "/runtime/" + name;
			if (FileSystem.exists(candidate)) return candidate;
		} catch (_:Dynamic) {}
		return null;
	}

	// -------------------------------------------------------------------------
	// Native bundle sync (jniLibs + assets, opt-in via aui.json#android)
	// -------------------------------------------------------------------------

	// Mirror native libraries and asset directories declared in aui.json#android
	// into android/app/src/main/{jniLibs,assets}. Runs on every haxe compile so
	// changes to source files propagate without manual copies. Each file is only
	// rewritten when the destination is missing, has a different size, or the
	// source mtime is newer — keeps incremental builds fast.
	static function syncNativeBundle(cfg:AndroidPackagingConfig):Void {
		var copied = 0;
		var skipped = 0;
		var missing:Array<String> = [];

		if (cfg.jniLibs != null) {
			for (abi in Reflect.fields(cfg.jniLibs)) {
				var libsForAbi:Dynamic = Reflect.field(cfg.jniLibs, abi);
				var destDir = "android/app/src/main/jniLibs/" + abi;
				ensureDir(destDir);
				for (destName in Reflect.fields(libsForAbi)) {
					var srcPath:String = Reflect.field(libsForAbi, destName);
					if (!FileSystem.exists(srcPath)) {
						missing.push("jniLibs[" + abi + "][" + destName + "] = " + srcPath);
						continue;
					}
					var dstPath = destDir + "/" + destName;
					if (copyIfNewer(srcPath, dstPath)) copied++; else skipped++;
				}
			}
		}

		if (cfg.assets != null) {
			for (destSub in Reflect.fields(cfg.assets)) {
				var srcDir:String = Reflect.field(cfg.assets, destSub);
				if (!FileSystem.exists(srcDir) || !FileSystem.isDirectory(srcDir)) {
					missing.push("assets[" + destSub + "] = " + srcDir + " (not a directory)");
					continue;
				}
				var destDir = "android/app/src/main/assets/" + destSub;
				var stats = mirrorDir(srcDir, destDir);
				copied += stats.copied;
				skipped += stats.skipped;
			}
		}

		if (missing.length > 0) {
			Context.warning('[AUI] nativeBundle: missing sources — ' + missing.join("; "), Context.currentPos());
		}
		if (copied > 0) {
			Context.warning('[AUI] nativeBundle: ' + copied + ' file(s) copied, ' + skipped + ' up-to-date', Context.currentPos());
		}
	}

	// Returns true if a copy actually happened, false if the destination was already current.
	static function copyIfNewer(src:String, dst:String):Bool {
		if (!FileSystem.exists(src)) return false;
		var srcStat = FileSystem.stat(src);
		if (FileSystem.exists(dst)) {
			var dstStat = FileSystem.stat(dst);
			if (dstStat.size == srcStat.size && dstStat.mtime.getTime() >= srcStat.mtime.getTime()) {
				return false;
			}
		}
		File.copy(src, dst);
		return true;
	}

	// Recursively mirror srcDir → destDir. Returns counters for telemetry.
	// Does not delete files in destDir that no longer exist in srcDir — the build
	// step doesn't own destDir exclusively (other tooling might add files), so we
	// stay conservative and only add/update.
	static function mirrorDir(srcDir:String, destDir:String):{copied:Int, skipped:Int} {
		ensureDir(destDir);
		var copied = 0;
		var skipped = 0;
		for (entry in FileSystem.readDirectory(srcDir)) {
			var srcPath = srcDir + "/" + entry;
			var dstPath = destDir + "/" + entry;
			if (FileSystem.isDirectory(srcPath)) {
				var sub = mirrorDir(srcPath, dstPath);
				copied += sub.copied;
				skipped += sub.skipped;
			} else {
				if (copyIfNewer(srcPath, dstPath)) copied++; else skipped++;
			}
		}
		return {copied: copied, skipped: skipped};
	}

	// -------------------------------------------------------------------------
	// Helpers
	// -------------------------------------------------------------------------

	static function escapeString(s:String):String {
		var r = StringTools.replace(s, "\\", "\\\\");
		r = StringTools.replace(r, '"', '\\"');
		r = StringTools.replace(r, "$", "\\$");
		r = StringTools.replace(r, "\n", "\\n");
		r = StringTools.replace(r, "\r", "\\r");
		r = StringTools.replace(r, "\t", "\\t");
		return r;
	}

	static function haxeTypeToKotlin(type:Type):String {
		switch (type) {
			case TAbstract(ref, _):
				switch (ref.get().name) {
					case "Int": return "Int";
					case "Float": return "Float";
					case "Bool": return "Boolean";
					default: return "Any";
				}
			case TInst(ref, params):
				switch (ref.get().name) {
					case "String": return "String";
					// Keep the element type. `List<Any>` compiled for as long as
					// nothing named an element: the moment a closure-form ForEach
					// binds one, `Text(text = item)` fails because Text wants a
					// String and the cast had erased it.
					case "Array" | "ImmutableList":
						return "List<" + (params.length > 0 ? haxeTypeToKotlin(params[0]) : "Any") + ">";
					default: return "Any";
				}
			default:
				return "Any";
		}
	}

	static function getDefaultForKotlinType(type:String):String {
		switch (type) {
			case "Int": return "0";
			case "Float": return "0f";
			case "Boolean": return "false";
			case "String": return '""';
			default: return "null";
		}
	}

	static function getIndent():String {
		var buf = new StringBuf();
		for (i in 0..._indent) buf.add("    ");
		return buf.toString();
	}

	static function ensureDir(path:String):Void {
		if (!FileSystem.exists(path)) {
			var parts = path.split("/");
			var current = "";
			for (part in parts) {
				current += part + "/";
				if (!FileSystem.exists(current)) FileSystem.createDirectory(current);
			}
		}
	}

	// -------------------------------------------------------------------------
	// Dynamic renderer coverage
	// -------------------------------------------------------------------------

	/**
		Refuse, at compile time, a view the dynamic renderer cannot draw.

		`?TabView` on screen was the wrong answer. It is the right one for a tree
		that arrives as **data** -- an interface streamed from a live source,
		which nothing can check ahead of time -- and that is the same boundary
		`wui` draws with `Foreign.node`. But a `body()` written here, compiled
		for a known renderer, can be judged now. Treating a knowable defect as
		unknowable is how a blank screen reaches a developer.

		The covered types are **read from the renderer itself**. Keeping a list
		here would be a second copy of the same knowledge -- the mistake this
		ecosystem pays for over and over -- and it would drift in the direction
		that hurts: a type dropped from the Kotlin would still pass the check.
	**/
	static function checkDynamicCoverage(types:Array<ModuleType>):Void {
		var covered = coveredViewTypes();
		if (covered == null) return; // already reported

		var offenders:Array<{name:String, pos:haxe.macro.Expr.Position}> = [];

		for (mt in types) {
			switch (mt) {
				case TClassDecl(ref):
					var cls = ref.get();
					if (!isAppSubclass(cls)) continue;
					for (field in cls.fields.get()) collectViews(field, covered, offenders);
					for (field in cls.statics.get()) collectViews(field, covered, offenders);
				default:
			}
		}

		if (offenders.length == 0) return;

		var known = [for (k in covered.keys()) k];
		known.sort(Reflect.compare);

		for (i in 0...offenders.length) {
			var o = offenders[i];
			var msg = 'The dynamic renderer cannot draw "' + o.name + '".\n'
				+ '  Covered types: ' + known.join(", ") + '.\n'
				+ '  Add it to the when() in aui/runtime/DynamicComposable.kt.';
			if (i == offenders.length - 1) Context.error(msg, o.pos);
			else Context.reportError(msg, o.pos);
		}
	}

	/**
		The types the Kotlin renderer switches on, read from its source.

		Deliberately parsed rather than re-declared: the `when` in `DynamicView`
		*is* the vocabulary, so anything else is a copy. Returns `null` after
		reporting, so a renderer that cannot be read stops the build instead of
		silently approving every type -- an absence must not read as approval.
	**/
	static function coveredViewTypes():Null<Map<String, Bool>> {
		var path = locateAuiRuntimeFile("DynamicComposable.kt");
		if (path == null) {
			Context.error('[AUI] DynamicComposable.kt not found: cannot check what the dynamic renderer covers.', Context.currentPos());
			return null;
		}

		// Only `DynamicView`'s when(): `applyModifiers` has one too, and its
		// branches are modifier names -- reading both would answer "Padding is a
		// view type", which is worse than not checking.
		var source = File.getContent(path);
		var from = source.indexOf("fun DynamicView(");
		var to = source.indexOf("fun applyModifiers(");
		if (from < 0 || to < 0 || to < from) {
			Context.error('[AUI] DynamicComposable.kt is not in the expected shape (DynamicView then applyModifiers): the check cannot assert anything.', Context.currentPos());
			return null;
		}

		var out = new Map<String, Bool>();
		var branch = ~/^\s*"([A-Za-z0-9_]+)"\s*->/;
		for (line in source.substring(from, to).split("\n")) {
			if (branch.match(line)) out.set(branch.matched(1), true);
		}

		if (!out.keys().hasNext()) {
			Context.error('[AUI] No type recognised in the when() of DynamicComposable.kt: the check cannot assert anything.', Context.currentPos());
			return null;
		}
		return out;
	}

	static function isAppSubclass(cls:ClassType):Bool {
		var current = cls.superClass == null ? null : cls.superClass.t.get();
		while (current != null) {
			if (current.name == "App" && current.pack.join(".") == "aui") return true;
			current = current.superClass == null ? null : current.superClass.t.get();
		}
		return false;
	}

	/**
		Collect `new aui.ui.X(...)` from a field that builds views.

		`body()` and the helpers it calls -- any method of the app returning a
		`View`, which is what `taskItem(...)` is -- and no others: a view built
		somewhere that never reaches the screen is not this check's business.
	**/
	static function collectViews(field:ClassField, covered:Map<String, Bool>,
			offenders:Array<{name:String, pos:haxe.macro.Expr.Position}>):Void {
		if (field.name != "body" && !buildsViews(field)) return;
		var e = field.expr();
		if (e != null) walkForViews(e, covered, offenders);
	}

	static function buildsViews(field:ClassField):Bool {
		return switch (haxe.macro.TypeTools.follow(field.type)) {
			case TFun(_, ret): isViewType(ret);
			case _: false;
		};
	}

	static function isViewType(t:haxe.macro.Type):Bool {
		return switch (haxe.macro.TypeTools.follow(t)) {
			case TInst(ref, _):
				var cls = ref.get();
				while (cls != null) {
					if (cls.name == "View" && cls.pack.join(".") == "aui") return true;
					cls = cls.superClass == null ? null : cls.superClass.t.get();
				}
				false;
			case _: false;
		};
	}

	/** Does this class name denote a ViewComponent subclass? **/
	static function isComponentName(fullName:String):Bool {
		try {
			switch (Context.follow(Context.getType(fullName))) {
				case TInst(ref, _): return isComponent(ref.get());
				case _: return false;
			}
		} catch (_:Dynamic) {
			return false;
		}
	}

	/**
		Whether the renderer draws this class, or a class it inherits from.

		The check is about the `viewType` a node carries, and a subclass carries
		its parent's unless it sets its own. `mui.ui.TextInput` extends
		`aui.ui.TextField` and reports `"TextField"` at runtime — judging it by
		its Haxe name refused a type the renderer draws perfectly well, and the
		message named a type nobody had written.

		A class that renames itself is still caught: it has to set `viewType`,
		and then nothing in the chain matches.
	**/
	static function coveredByChain(cls:ClassType, covered:Map<String, Bool>):Bool {
		var current = cls;
		while (current != null) {
			if (covered.exists(current.name)) return true;
			current = current.superClass == null ? null : current.superClass.t.get();
		}
		return false;
	}

	/**
		A node with no rendering of its own, expanded before any renderer sees
		it: a `ViewComponent` into its `body()`, a `ForEach` into its items.
	**/
	static function isExpanded(cls:ClassType):Bool {
		if (isComponent(cls)) return true;
		return cls.name == "ForEach" && cls.pack.join(".") == "aui.ui";
	}

	/** A composition unit, expanded rather than drawn. **/
	static function isComponent(cls:ClassType):Bool {
		var current = cls;
		while (current != null) {
			if (current.name == "ViewComponent" && current.pack.join(".") == "aui") return true;
			current = current.superClass == null ? null : current.superClass.t.get();
		}
		return false;
	}

	static function extendsView(cls:ClassType):Bool {
		var current = cls;
		while (current != null) {
			if (current.name == "View" && current.pack.join(".") == "aui") return true;
			current = current.superClass == null ? null : current.superClass.t.get();
		}
		return false;
	}

	static function walkForViews(e:TypedExpr, covered:Map<String, Bool>,
			offenders:Array<{name:String, pos:haxe.macro.Expr.Position}>):Void {
		if (e == null) return;

		switch (e.expr) {
			case TNew(ref, _, _):
				var cls = ref.get();
				// Only renderable nodes.
				//
				// `aui.ui.Tab` is a plain class carrying a title and a content
				// view -- it never becomes a node, so demanding a branch for it
				// would be asking for dead code. A `ViewComponent` is expanded
				// into what its body() returns, so it is never drawn either, and
				// neither is a `ForEach` -- it is spliced into its parent's
				// children by `aui.nui.ViewSource.childrenOf`.
				//
				// Everything else that is a View is judged, **including a type the
				// application declared itself**. Restricting this to `aui.ui` was
				// an angle only our own code was watched from: a user's
				// `class Badge extends View` compiled clean and drew `?Badge` on
				// the screen -- the silent failure this check exists to remove,
				// left in place for exactly the people it should protect.
				if (extendsView(cls) && !isExpanded(cls) && !coveredByChain(cls, covered)) {
					offenders.push({name: cls.name, pos: e.pos});
				}
			default:
		}

		haxe.macro.TypedExprTools.iter(e, function(sub) walkForViews(sub, covered, offenders));
	}
}
#end
