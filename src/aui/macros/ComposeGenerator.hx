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

	public static function register():Void {
		Context.onAfterTyping(function(modules:Array<ModuleType>) {
			// Pass 1: Collect types
			for (module in modules) {
				switch (module) {
					case TClassDecl(ref):
						var cls = ref.get();
						var fullName = cls.pack.join(".") + (cls.pack.length > 0 ? "." : "") + cls.name;

						// Check if it extends aui.App
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

						// Check if it extends aui.state.Observable
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
			if (_appClass == null) {
				return;
			}
			generateComposeFiles();
		});
	}

	static function generateComposeFiles():Void {
		// Ensure output directory exists
		ensureDir(_outputDir);

		// Get the App class type info to extract body() expression
		var appType = Context.getType(_appClass);
		var appName = "HaxeApp";
		var packageName = "com.haxe.app";

		// Read config from aui.json if it exists
		if (FileSystem.exists("aui.json")) {
			try {
				var configContent = File.getContent("aui.json");
				var config = haxe.Json.parse(configContent);
				if (config.appName != null) appName = config.appName;
				if (config.packageName != null) packageName = config.packageName;
			} catch (e:Dynamic) {
				// Fall back to defaults
			}
		}

		// Read full config for Gradle generation
		var minSdk = 24;
		var targetSdk = 35;
		var compileSdk = 35;
		if (FileSystem.exists("aui.json")) {
			try {
				var configContent = File.getContent("aui.json");
				var config = haxe.Json.parse(configContent);
				if (config.minSdk != null) minSdk = config.minSdk;
				if (config.targetSdk != null) targetSdk = config.targetSdk;
				if (config.compileSdk != null) compileSdk = config.compileSdk;
			} catch (e:Dynamic) {}
		}

		// Generate Android project structure if needed
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

		// Generate MainActivity.kt
		generateMainActivity(packageName, appName);

		// Generate MainScreen.kt from body()
		generateMainScreen(packageName, appType);

		// Generate AppState.kt if there are state fields
		generateAppState(packageName, appType);

		Context.warning('[AUI] Generated Compose files in ${_outputDir}', Context.currentPos());
	}

	static function generateMainActivity(packageName:String, appName:String):Void {
		var buf = new StringBuf();
		buf.add('package ${packageName}\n\n');
		buf.add('import android.os.Bundle\n');
		buf.add('import androidx.activity.ComponentActivity\n');
		buf.add('import androidx.activity.compose.setContent\n');
		buf.add('import androidx.compose.material3.MaterialTheme\n');
		buf.add('import androidx.compose.material3.Surface\n\n');
		buf.add('class MainActivity : ComponentActivity() {\n');
		buf.add('    override fun onCreate(savedInstanceState: Bundle?) {\n');
		buf.add('        super.onCreate(savedInstanceState)\n');
		buf.add('        setContent {\n');
		buf.add('            MaterialTheme {\n');
		buf.add('                Surface {\n');
		buf.add('                    MainScreen()\n');
		buf.add('                }\n');
		buf.add('            }\n');
		buf.add('        }\n');
		buf.add('    }\n');
		buf.add('}\n');

		File.saveContent('${_outputDir}/MainActivity.kt', buf.toString());
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
		buf.add('package ${packageName}\n\n');
		buf.add('import androidx.compose.foundation.layout.*\n');
		buf.add('import androidx.compose.material3.*\n');
		buf.add('import androidx.compose.runtime.*\n');
		buf.add('import androidx.compose.ui.Alignment\n');
		buf.add('import androidx.compose.ui.Modifier\n');
		buf.add('import androidx.compose.ui.unit.dp\n');
		buf.add('import androidx.compose.ui.unit.sp\n');
		buf.add('import androidx.compose.ui.graphics.Color\n');
		buf.add('import androidx.compose.ui.text.font.FontWeight\n');
		buf.add('import androidx.compose.ui.text.font.FontStyle\n');
		buf.add('import androidx.compose.ui.text.style.TextAlign\n');
		buf.add('import androidx.compose.ui.draw.*\n\n');

		buf.add('@Composable\n');
		buf.add('fun MainScreen() {\n');

		if (bodyExpr != null) {
			_indent = 1;
			var bodyCode = translateTypedExpr(bodyExpr);
			buf.add(bodyCode);
		} else {
			buf.add('    // No body() defined\n');
			buf.add('    Text("Hello from AUI!")\n');
		}

		buf.add('}\n');

		File.saveContent('${_outputDir}/MainScreen.kt', buf.toString());
	}

	static function generateAppState(packageName:String, appType:Type):Void {
		var stateFields:Array<{name:String, type:String, defaultValue:String}> = [];

		switch (appType) {
			case TInst(ref, _):
				var cls = ref.get();
				for (field in cls.fields.get()) {
					// Look for State<T> fields
					switch (field.type) {
						case TInst(tref, params):
							var typeName = tref.get().pack.join(".") + (tref.get().pack.length > 0 ? "." : "") + tref.get().name;
							if (typeName == "aui.state.State" && params.length > 0) {
								var kotlinType = haxeTypeToKotlin(params[0]);
								stateFields.push({
									name: field.name,
									type: kotlinType,
									defaultValue: getDefaultForKotlinType(kotlinType)
								});
							}
						default:
					}
				}
			default:
		}

		if (stateFields.length == 0) {
			return;
		}

		var buf = new StringBuf();
		buf.add('package ${packageName}\n\n');
		buf.add('import androidx.compose.runtime.mutableStateOf\n');
		buf.add('import androidx.compose.runtime.getValue\n');
		buf.add('import androidx.compose.runtime.setValue\n');
		buf.add('import androidx.lifecycle.ViewModel\n\n');
		buf.add('class AppState : ViewModel() {\n');

		for (field in stateFields) {
			buf.add('    var ${field.name} by mutableStateOf(${field.defaultValue})\n');
		}

		buf.add('\n    companion object {\n');
		buf.add('        private val _instance = AppState()\n');
		buf.add('        fun getShared(): AppState = _instance\n');
		buf.add('    }\n');
		buf.add('}\n');

		File.saveContent('${_outputDir}/AppState.kt', buf.toString());
	}

	// --- AST Translation ---

	// A modifier collected from the chain
	static var _viewModifiers:Array<{name:String, args:Array<TypedExpr>}> = [];

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
				// Check if this is a modifier chain: someView.modifier(args)
				switch (func.expr) {
					case TField(innerExpr, fa):
						var fieldName = getFieldName(fa);
						if (isModifierMethod(fieldName)) {
							// Unwrap the full modifier chain
							var modifiers:Array<{name:String, args:Array<TypedExpr>}> = [];
							modifiers.push({name: fieldName, args: args});
							var baseExpr = unwrapModifierChain(innerExpr, modifiers);
							// Now baseExpr is the TNew and modifiers has all collected modifiers (in reverse order)
							modifiers.reverse();
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

	static function translateViewWithModifiers(fullName:String, args:Array<TypedExpr>,
			modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var indent = getIndent();

		// Build Modifier chain string
		var modStr = buildModifierChain(modifiers);
		// Collect text-specific modifiers (font, bold, etc.)
		var textParams = extractTextParams(modifiers);

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
				if (modStr.length > 0) {
					return '${indent}Spacer(modifier = ${modStr})\n';
				}
				return '${indent}Spacer(modifier = Modifier.weight(1f))\n';

			case "aui.ui.Button":
				return generateButton(args, modStr, indent);

			default:
				return '${indent}// Unknown view: ${fullName}\n';
		}
	}

	static function generateText(args:Array<TypedExpr>, modifiers:Array<{name:String, args:Array<TypedExpr>}>,
			indent:String):String {
		var textContent = '""';
		if (args.length > 0) {
			textContent = translateTypedExpr(args[0]);
		}

		// Check for bold/italic
		var hasBold = false;
		var hasItalic = false;
		for (mod in modifiers) {
			if (mod.name == "bold") hasBold = true;
			if (mod.name == "italic") hasItalic = true;
		}

		// Build Modifier chain for layout modifiers
		var layoutMods = buildModifierChain(modifiers);

		var buf = new StringBuf();
		buf.add('${indent}Text(\n');
		buf.add('${indent}    text = ${textContent}');

		for (mod in modifiers) {
			if (mod.name == "foregroundColor" && mod.args.length > 0) {
				buf.add(',\n${indent}    color = ${translateColorArg(mod.args[0])}');
			}
		}

		// Use style parameter for font (the proper Compose API)
		for (mod in modifiers) {
			if (mod.name == "font" && mod.args.length > 0) {
				var fontInfo = translateFontArg(mod.args[0]);
				if (fontInfo.style != null) {
					buf.add(',\n${indent}    style = ${fontInfo.style}');
				}
			}
		}

		if (hasBold) {
			buf.add(',\n${indent}    fontWeight = FontWeight.Bold');
		}
		if (hasItalic) {
			buf.add(',\n${indent}    fontStyle = FontStyle.Italic');
		}

		for (mod in modifiers) {
			if (mod.name == "multilineTextAlignment" && mod.args.length > 0) {
				buf.add(',\n${indent}    textAlign = ${translateTextAlignArg(mod.args[0])}');
			}
		}

		if (layoutMods.length > 0) {
			buf.add(',\n${indent}    modifier = ${layoutMods}');
		}

		buf.add('\n${indent})\n');
		return buf.toString();
	}

	static function generateContainer(composeName:String, args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();

		// Find the content array argument
		var contentArg:Null<TypedExpr> = null;
		for (arg in args) {
			switch (arg.expr) {
				case TArrayDecl(_):
					contentArg = arg;
				default:
			}
		}

		// Build parameters
		var params = new Array<String>();
		if (modStr.length > 0) {
			params.push('modifier = ${modStr}');
		}
		if (composeName == "Column") {
			params.push('horizontalAlignment = Alignment.CenterHorizontally');
		} else if (composeName == "Row") {
			params.push('verticalAlignment = Alignment.CenterVertically');
		}

		if (params.length > 0) {
			buf.add('${indent}${composeName}(\n');
			for (i in 0...params.length) {
				buf.add('${indent}    ${params[i]}');
				if (i < params.length - 1) buf.add(',');
				buf.add('\n');
			}
			buf.add('${indent}) {\n');
		} else {
			buf.add('${indent}${composeName} {\n');
		}

		// Translate children
		if (contentArg != null) {
			switch (contentArg.expr) {
				case TArrayDecl(elements):
					_indent++;
					for (element in elements) {
						buf.add(translateTypedExpr(element));
					}
					_indent--;
				default:
			}
		}

		buf.add('${indent}}\n');
		return buf.toString();
	}

	static function generateButton(args:Array<TypedExpr>, modStr:String, indent:String):String {
		var buf = new StringBuf();
		var label = '""';
		if (args.length > 0) {
			label = translateTypedExpr(args[0]);
		}

		buf.add('${indent}Button(\n');
		buf.add('${indent}    onClick = { /* action */ }');
		if (modStr.length > 0) {
			buf.add(',\n${indent}    modifier = ${modStr}');
		}
		buf.add('\n${indent}) {\n');
		buf.add('${indent}    Text(${label})\n');
		buf.add('${indent}}\n');
		return buf.toString();
	}

	// --- Modifier Translation ---

	static function buildModifierChain(modifiers:Array<{name:String, args:Array<TypedExpr>}>):String {
		var parts = new Array<String>();

		for (mod in modifiers) {
			var part = translateSingleModifier(mod.name, mod.args);
			if (part.length > 0) {
				parts.push(part);
			}
		}

		if (parts.length == 0) return "";
		return "Modifier" + parts.join("");
	}

	static function translateSingleModifier(name:String, args:Array<TypedExpr>):String {
		switch (name) {
			case "padding":
				if (args.length > 0) {
					var value = translateTypedExpr(args[0]);
					if (value == "null" || value == "") return '.padding(16.dp)';
					return '.padding(${value}.dp)';
				}
				return '.padding(16.dp)';

			case "background":
				if (args.length > 0) {
					return '.background(${translateColorArg(args[0])})';
				}
				return "";

			case "cornerRadius":
				if (args.length > 0) {
					var value = translateTypedExpr(args[0]);
					return '.clip(RoundedCornerShape(${value}.dp))';
				}
				return "";

			case "opacity":
				if (args.length > 0) {
					var value = translateTypedExpr(args[0]);
					return '.alpha(${value}f)';
				}
				return "";

			case "frame":
				var parts = new Array<String>();
				if (args.length > 0) parts.push('width = ${translateTypedExpr(args[0])}.dp');
				if (args.length > 1) parts.push('height = ${translateTypedExpr(args[1])}.dp');
				if (parts.length > 0) return '.size(${parts.join(", ")})';
				return "";

			case "offset":
				if (args.length >= 2) {
					return '.offset(x = ${translateTypedExpr(args[0])}.dp, y = ${translateTypedExpr(args[1])}.dp)';
				}
				return "";

			case "blur":
				if (args.length > 0) {
					return '.blur(${translateTypedExpr(args[0])}.dp)';
				}
				return "";

			case "scaleEffect":
				if (args.length > 0) {
					return '.scale(${translateTypedExpr(args[0])}f)';
				}
				return "";

			case "rotationEffect":
				if (args.length > 0) {
					return '.rotate(${translateTypedExpr(args[0])}f)';
				}
				return "";

			case "hidden":
				return '.alpha(0f)';

			case "disabled":
				// Disabled is typically handled at the component level, not via Modifier
				return "";

			case "shadow":
				return '.shadow(elevation = 4.dp)';

			case "border":
				if (args.length > 0) {
					var color = translateColorArg(args[0]);
					var width = args.length > 1 ? translateTypedExpr(args[1]) : "1";
					return '.border(${width}.dp, ${color})';
				}
				return "";

			// Text-specific modifiers handled in generateText, not in Modifier chain
			case "font", "bold", "italic", "foregroundColor", "lineLimit",
				"multilineTextAlignment":
				return "";

			default:
				return '/* ${name} */';
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

	static function translateColorArg(expr:TypedExpr):String {
		switch (expr.expr) {
			case TField(_, fa):
				var name = getFieldName(fa);
				switch (name) {
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
				var name = getFieldName(fa);
				switch (name) {
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
				var name = getFieldName(fa);
				switch (name) {
					case "Start": return "TextAlign.Start";
					case "Center": return "TextAlign.Center";
					case "End": return "TextAlign.End";
					default: return "TextAlign.Start";
				}
			default:
				return "TextAlign.Start";
		}
	}

	static function escapeString(s:String):String {
		return StringTools.replace(StringTools.replace(s, "\\", "\\\\"), '"', '\\"');
	}

	// --- Helpers ---

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
		for (i in 0..._indent) {
			buf.add("    ");
		}
		return buf.toString();
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
