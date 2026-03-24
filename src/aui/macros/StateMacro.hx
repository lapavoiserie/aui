package aui.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

class StateMacro {
	public static function build():Array<Field> {
		var fields = Context.getBuildFields();
		var newFields:Array<Field> = [];
		var stateInits:Array<Expr> = [];

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
				newFields.push(field);
			}
		}

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

		return newFields;
	}
}
#end
