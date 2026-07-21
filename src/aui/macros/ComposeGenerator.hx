package aui.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;
import sys.FileSystem;
import sys.io.File;

class ComposeGenerator {
	static var _appClass:Null<String> = null;
	static var _appModule:Null<String> = null;
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

	public static function register():Void {
		Context.onAfterTyping(function(modules:Array<ModuleType>) {
			for (module in modules) {
				switch (module) {
					case TClassDecl(ref):
						var cls = ref.get();
						var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;

						var superClass = cls.superClass;
						while (superClass != null) {
							var superRef = superClass.t.get();
							var superName = superRef.pack.join(".") + (superRef.pack.length > 0 ? "." : "") + superRef.name;
							if (superName == "aui.App") {
								_appClass = fullName;
								_appModule = cls.module;
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
			if (_appClass == null) return;
			generateComposeFiles();
		});
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
		generateMainScreen(packageName, appType);

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
			"import androidx.compose.material3.MaterialTheme",
			"import androidx.compose.material3.Surface",
			"",
			"class MainActivity : ComponentActivity() {",
			"    override fun onCreate(savedInstanceState: Bundle?) {",
			"        super.onCreate(savedInstanceState)",
			"        // Construct the Haxe App instance: this initializes its @:state",
			"        // fields, each backed by a Compose MutableState via",
			"        // aui.state.StateBridge — reactive throughout the lifetime of",
			"        // the Activity.",
			"        val app = " + jvmApp + "()",
			"        // AUI lifecycle hook: invoked once before composition, gives the",
			"        // app a chance to bootstrap with the Android Context (extract",
			"        // assets, set up symlinks, register JNI bridges, etc.).",
			"        app.onAndroidContextReady(",
			"            applicationInfo.nativeLibraryDir,",
			"            filesDir.absolutePath,",
			"            assets",
			"        )",
			"        setContent {",
			"            MaterialTheme {",
			"                Surface {",
			"                    MainScreen(app)",
			"                }",
			"            }",
			"        }",
			"    }",
			"}",
			""
		];
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
				viewCode = indent + "// Unknown view: " + fullName + "\n";
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
		var builderBody:Null<TypedExpr> = null;

		switch (args[1].expr) {
			case TFunction(tf):
				if (tf.args.length > 0) {
					paramName = tf.args[0].v.name;
				}
				builderBody = tf.expr;
			default:
		}

		buf.add(indent + collectionExpr + ".forEachIndexed { index, " + paramName + " ->\n");
		if (builderBody != null) {
			_indent++;
			buf.add(translateTypedExpr(builderBody));
			_indent--;
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
			var anchor = Context.resolvePath("aui/state/State.hx"); // aui/src/aui/state/State.hx
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
			case TInst(ref, _):
				switch (ref.get().name) {
					case "String": return "String";
					case "Array": return "List<Any>";
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
}
#end
