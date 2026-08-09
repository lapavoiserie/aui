package aui.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;
import haxe.macro.Type;

class StateMacro {
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var newFields:Array<Field> = [];
		var stateInits:Array<Expr> = [];

		// Closure lifting: each anonymous closure passed as the action arg of
		// `new Button(...)` is lifted to a public method on the App class.
		// The Button arg is rewritten to a method reference. At runtime the
		// generated Kotlin invokes `app.<methodName>()` from `onClick`, executing
		// the original Haxe code as compiled JVM bytecode (no AST translation,
		// no scope capture games — Haxe handles `this` naturally).
		var liftedClosures:Array<Field> = [];
		var liftCounter = 0;

		function tryLiftClosure(closureExpr:Expr):Expr {
			if (closureExpr == null) return closureExpr;
			return switch (closureExpr.expr) {
				case EFunction(FAnonymous | FArrow, fun) if (fun.args.length == 0 && fun.expr != null):
					var name = "__aui_action_" + (liftCounter++);
					liftedClosures.push({
						name: name,
						access: [APublic],
						kind: FFun({args: [], ret: macro:Void, expr: fun.expr}),
						pos: closureExpr.pos
					});
					macro this.$name;
				default:
					closureExpr;
			}
		}

		function liftClosuresInExpr(expr:Expr):Expr {
			if (expr == null) return expr;
			return switch (expr.expr) {
				case ENew(typePath, args) if (typePath.name == "Button" && args.length >= 2):
					var newArgs = args.copy();
					newArgs[1] = tryLiftClosure(newArgs[1]);
					{expr: ENew(typePath, newArgs), pos: expr.pos};
				default:
					ExprTools.map(expr, liftClosuresInExpr);
			}
		}

		for (field in fields) {
			var isState = false;
			if (field.meta != null) {
				for (meta in field.meta) {
					if (meta.name == ":state") {
						isState = true;
						break;
					}
				}
			}

			if (isState) {
				// Transform @:state var count:Int = 0; into var count:State<Int>;
				switch (field.kind) {
					case FVar(t, e):
						var stateType = macro:aui.state.State<$t>;
						var fieldName = field.name;
						var defaultExpr = e != null ? e : macro null;

						field.kind = FVar(stateType, null);
						field.meta = []; // Remove @:state meta

						// Add initialization to constructor
						stateInits.push(macro this.$fieldName = new aui.state.State($defaultExpr, $v{fieldName}));

						newFields.push(field);
					default:
						newFields.push(field);
				}
			} else {
				// Walk body() and any other view-returning method to lift closures
				// passed to Button. Other UI elements (onTapGesture modifier on
				// non-Button views, onAppear, etc.) aren't lifted here yet — they
				// fall back to the codegen's existing `.clickable { }` no-op.
				switch (field.kind) {
					case FFun(f) if (f.expr != null):
						f.expr = liftClosuresInExpr(f.expr);
					default:
				}
				newFields.push(field);
			}
		}

		// Append lifted methods after the rest of the class.
		for (lc in liftedClosures) newFields.push(lc);

		// If there are state initializations, inject them into the constructor
		if (stateInits.length > 0) {
			var hasConstructor = false;
			for (field in newFields) {
				if (field.name == "new") {
					hasConstructor = true;
					switch (field.kind) {
						case FFun(f):
							var existingBody = f.expr;
							var initBlock:Array<Expr> = stateInits.copy();
							if (existingBody != null) {
								initBlock.push(existingBody);
							}
							f.expr = macro $b{initBlock};
						default:
					}
					break;
				}
			}

			if (!hasConstructor) {
				var initBlock:Array<Expr> = [macro super()].concat(stateInits);
				newFields.push({
					name: "new",
					access: [APublic],
					kind: FFun({
						args: [],
						ret: null,
						expr: macro $b{initBlock}
					}),
					pos: Context.currentPos()
				});
			}
		}

		// Defer view values into thunks, so a read lands in the composable that
		// displays it rather than the one that built the tree. Dynamic path
		// only; see aui.macros.LiveProps.
		return LiveProps.apply(newFields);
	}
}
#end
