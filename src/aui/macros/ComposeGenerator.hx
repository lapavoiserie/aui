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

		if (FileSystem.exists("aui.json")) {
			try {
				var json = haxe.Json.parse(File.getContent("aui.json"));
				if (json.appName != null) appName = json.appName;
				if (json.packageName != null) packageName = json.packageName;
				if (json.minSdk != null) minSdk = json.minSdk;
				if (json.targetSdk != null) targetSdk = json.targetSdk;
				if (json.compileSdk != null) compileSdk = json.compileSdk;
			} catch (e:Dynamic) {}
		}

		// Collect state fields from the App subclass
		_stateFields = collectStateFields(appType);

		// Generate Gradle project if needed
		if (!FileSystem.exists("android/build.gradle.kts")) {
			GradleProject.generate({
				appName: appName,
				packageName: packageName,
				minSdk: minSdk,
				targetSdk: targetSdk,
				compileSdk: compileSdk
			});
			Context.warning('[AUI] Generated Android project in android/', Context.currentPos());
		}

		generateMainActivity(packageName, appName);
		generateMainScreen(packageName, appType);

		Context.warning('[AUI] Generated Compose files in ${_outputDir}', Context.currentPos());
	}

	static function collectStateFields(appType:Type):Array<{name:String, type:String, defaultValue:String}> {
		var fields:Array<{name:String, type:String, defaultValue:String}> = [];

		switch (appType) {
			case TInst(ref, _):
				var cls = ref.get();
				for (field in cls.fields.get()) {
					switch (field.type) {
						case TInst(tref, params):
							var typeName = tref.get().pack.join(".") + (tref.get().pack.length > 0 ? "." : "") + tref.get().name;
							if (typeName == "aui.state.State" && params.length > 0) {
								var kotlinType = haxeTypeToKotlin(params[0]);
								// Try to get default value from field expr
								var defVal = getDefaultForKotlinType(kotlinType);
								var expr = field.expr();
								if (expr != null) {
									var extracted = extractDefaultValue(expr);
									if (extracted != null) defVal = extracted;
								}
								fields.push({name: field.name, type: kotlinType, defaultValue: defVal});
							}
						default:
					}
				}
			default:
		}

		return fields;
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
	// File generators
	// -------------------------------------------------------------------------

	static function generateMainActivity(packageName:String, appName:String):Void {
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
			"        setContent {",
			"            MaterialTheme {",
			"                Surface {",
			"                    MainScreen()",
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

		var buf = new StringBuf();
		buf.add("package " + packageName + "\n\n");

		// Imports
		var imports = [
			"androidx.compose.foundation.layout.*",
			"androidx.compose.foundation.rememberScrollState",
			"androidx.compose.foundation.verticalScroll",
			"androidx.compose.material3.*",
			"androidx.compose.runtime.*",
			"androidx.compose.ui.Alignment",
			"androidx.compose.ui.Modifier",
			"androidx.compose.ui.unit.dp",
			"androidx.compose.ui.unit.sp",
			"androidx.compose.ui.graphics.Color",
			"androidx.compose.ui.text.font.FontWeight",
			"androidx.compose.ui.text.font.FontStyle",
			"androidx.compose.ui.text.style.TextAlign",
			"androidx.compose.ui.text.input.PasswordVisualTransformation",
			"androidx.compose.ui.draw.*"
		];
		for (imp in imports) {
			buf.add("import " + imp + "\n");
		}
		buf.add("\n");

		buf.add("@Composable\n");
		buf.add("fun MainScreen() {\n");

		// Emit state declarations
		for (sf in _stateFields) {
			buf.add("    var " + sf.name + " by remember { mutableStateOf(" + sf.defaultValue + ") }\n");
		}
		if (_stateFields.length > 0) {
			buf.add("\n");
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
				var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
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
									var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;
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

		// Convert {varName} → $varName for Kotlin string interpolation
		var reg = ~/\{([^}]+)\}/g;
		var kotlinStr = reg.map(template, function(r) {
			return "$" + r.matched(1);
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
			"padding", "frame", "offset", "aspectRatio",
			"font", "bold", "italic", "lineLimit", "multilineTextAlignment",
			"foregroundColor", "background", "opacity", "cornerRadius",
			"clipShape", "shadow", "blur", "scaleEffect", "rotationEffect",
			"brightness", "contrast", "saturation", "grayscale",
			"border", "overlay",
			"onTapGesture", "onLongPressGesture", "onAppear", "onDisappear",
			"disabled", "hidden",
			"navigationTitle", "accessibilityLabel"
		].indexOf(name) != -1;
	}

	// -------------------------------------------------------------------------
	// View translation
	// -------------------------------------------------------------------------

	static function translateViewWithModifiers(fullName:String, args:Array<TypedExpr>,
			modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var indent = getIndent();
		var modStr = buildModifierChain(modifiers);

		switch (fullName) {
			case "aui.ui.Text":
				return generateText(args, modifiers, indent);
			case "aui.ui.VStack":
				return generateContainer("Column", args, modStr, indent);
			case "aui.ui.HStack":
				return generateContainer("Row", args, modStr, indent);
			case "aui.ui.ZStack":
				return generateContainer("Box", args, modStr, indent);
			case "aui.ui.Spacer":
				if (modStr.length > 0) return indent + "Spacer(modifier = " + modStr + ")\n";
				return indent + "Spacer(modifier = Modifier.weight(1f))\n";
			case "aui.ui.Button":
				return generateButton(args, modStr, indent);
			case "aui.ui.Divider":
				if (modStr.length > 0) return indent + "HorizontalDivider(modifier = " + modStr + ")\n";
				return indent + "HorizontalDivider()\n";
			case "aui.ui.TextField":
				return generateTextField(args, modStr, indent);
			case "aui.ui.Toggle":
				return generateToggle(args, modStr, indent);
			case "aui.ui.Slider":
				return generateSlider(args, modStr, indent);
			case "aui.ui.ScrollView":
				return generateScrollView(args, modStr, indent);
			case "aui.ui.Image":
				return generateImage(args, modStr, indent);
			case "aui.ui.ConditionalView":
				return generateConditionalView(args, indent);
			default:
				return indent + "// Unknown view: " + fullName + "\n";
		}
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

		// Try to translate the second argument as a StateAction
		var actionCode = "{ }";
		if (args.length >= 2) {
			var sa = translateStateAction(args[1]);
			if (sa != null) {
				actionCode = "{ " + sa + " }";
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

	static function generateTextField(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		var placeholder = '""';
		if (args.length > 0) placeholder = translateTypedExpr(args[0]);

		// Second arg is the State<String> binding
		var stateName:Null<String> = null;
		if (args.length >= 2) stateName = extractStateFieldName(args[1]);

		if (stateName != null) {
			buf.add(indent + "OutlinedTextField(\n");
			buf.add(indent + "    value = " + stateName + ",\n");
			buf.add(indent + "    onValueChange = { " + stateName + " = it },\n");
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
			buf.add(indent + "    Switch(checked = " + stateName + ", onCheckedChange = { " + stateName + " = it })\n");
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
			buf.add(indent + "    value = " + stateName + ".toFloat(),\n");
			buf.add(indent + "    onValueChange = { " + stateName + " = it },\n");
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
		var condVar = stateName != null ? stateName : "false";

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

						switch (methodName) {
							case "inc":
								if (args.length > 0) {
									var amount = translateTypedExpr(args[0]);
									if (amount != "null" && amount != "") return stateName + " += " + amount;
								}
								return stateName + "++";
							case "dec":
								if (args.length > 0) {
									var amount = translateTypedExpr(args[0]);
									if (amount != "null" && amount != "") return stateName + " -= " + amount;
								}
								return stateName + "--";
							case "setTo":
								if (args.length > 0) {
									var value = translateTypedExpr(args[0]);
									return stateName + " = " + value;
								}
								return null;
							case "tog":
								return stateName + " = !" + stateName;
							case "appendAction":
								if (args.length > 0) {
									var value = translateTypedExpr(args[0]);
									return stateName + " = " + stateName + " + " + value;
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
	// Handles: this.fieldName, fieldName (local)
	static function extractStateFieldName(expr:TypedExpr):Null<String> {
		switch (expr.expr) {
			case TField(_, fa):
				var name = getFieldName(fa);
				// Check if it's a known state field
				for (sf in _stateFields) {
					if (sf.name == name) return name;
				}
				return null;
			case TLocal(v):
				for (sf in _stateFields) {
					if (sf.name == v.name) return v.name;
				}
				return null;
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
			case "font", "bold", "italic", "foregroundColor", "lineLimit", "multilineTextAlignment":
				return ""; // Handled in generateText
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
	// Helpers
	// -------------------------------------------------------------------------

	static function escapeString(s:String):String {
		return StringTools.replace(StringTools.replace(s, "\\", "\\\\"), '"', '\\"');
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
