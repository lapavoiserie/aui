package aui.macros;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.ExprTools;
#end

/**
	Defers a view's *values* so they are read when the platform asks, not when
	`body()` ran.

	## The problem it solves

	`new Text("count: " + n.get())` computes its string during `body()`. Under the
	dynamic renderer that read happens inside `DynamicRoot`'s composition scope,
	so Compose attributes it to the whole tree: any write to `n` recomposes
	everything, rebuilding every node to change one string.

	The value has to be a **thunk** rather than a result. Then the read happens
	inside the `Text` composable, and Compose recomposes that alone.

	## The rewrite

	On the dynamic path, inside `body()` and any method declared to return a
	`View`:

	```haxe
	new Text("count: " + n.get())
	```

	becomes

	```haxe
	{ var __n = new Text(""); __n.liveBuild = () -> new Text("count: " + n.get()); __n; }
	```

	The node is built with **neutral values**, so constructing it reads no state
	at all; `liveBuild` carries the real expression, and the bridge calls it when
	a value is asked for.

	## What it deliberately does not touch

	- **Containers.** If any argument is a `View` or an array of them, the node is
	  left alone: re-running its constructor would rebuild its children and throw
	  away their identity.
	- **Non-value arguments.** A `StateAction`, a `State<T>`, a closure -- these are
	  identities, not values. They stay on the initial node, which is what
	  `invokeAction` and the editable controls read. Constructing them reads no
	  state either.
	- **Constants.** `new Text("hello")` has nothing to defer, so it is untouched.

	Nothing is rewritten unless at least one value argument was actually deferred.
**/
class LiveProps {
	#if macro
	/** Value types worth deferring: what a view *displays*. **/
	static function isDeferrableValue(t:Type):Bool {
		return switch (Context.follow(t)) {
			case TInst(ref, _): ref.get().name == "String";
			case TAbstract(ref, _):
				switch (ref.get().name) {
					case "Int" | "Float" | "Bool": true;
					case _: false;
				}
			case _: false;
		};
	}

	/** A view, or a collection of them: the sign of a container. **/
	static function isViewish(t:Type):Bool {
		return switch (Context.follow(t)) {
			case TInst(ref, params):
				var cls = ref.get();
				if (cls.name == "Array" && params.length > 0) return isViewish(params[0]);
				var c = cls;
				while (c != null) {
					if (c.name == "View" && c.pack.join(".") == "aui") return true;
					c = c.superClass == null ? null : c.superClass.t.get();
				}
				false;
			case _: false;
		};
	}

	static function neutralFor(t:Type):Expr {
		return switch (Context.follow(t)) {
			case TInst(ref, _) if (ref.get().name == "String"): macro "";
			case TAbstract(ref, _):
				switch (ref.get().name) {
					case "Int": macro 0;
					case "Float": macro 0.0;
					case "Bool": macro false;
					case _: macro null;
				}
			case _: macro null;
		};
	}

	/** Is this expression already a constant? Then there is nothing to defer. **/
	static function isConstant(e:Expr):Bool {
		return switch (e.expr) {
			// A single-quoted string is not a constant until the compiler has
			// looked inside it: Haxe keeps `'n = ${count.get()}'` as a CString
			// through the build pass, interpolation and all. Calling that
			// constant deferred nothing, so the read stayed in body() -- which
			// made the cell structural, so every write rebuilt the tree and the
			// whole screen flickered for a label changing by one digit.
			case EConst(CString(value, kind)):
				kind != SingleQuotes || value.indexOf("$") < 0;
			case EConst(CInt(_) | CFloat(_)): true;
			case EConst(CIdent("true" | "false" | "null")): true;
			case _: false;
		};
	}

	/** The constructor's parameter types, or null if they cannot be resolved. **/
	static function ctorArgTypes(tp:TypePath, pos:Position):Null<Array<Type>> {
		try {
			var t = Context.resolveType(TPath(tp), pos);
			switch (Context.follow(t)) {
				case TInst(ref, _):
					var cls = ref.get();
					// An aui view, or something that extends one. Restricting this
					// to the `aui.ui` package meant a framework layered on top got
					// no deferral: `mui.ui.Toggle` is an `aui.ui.Toggle` without
					// being in that package, so its values stayed computed during
					// body() -- which makes the cell structural, and every write
					// rebuilds the tree.
					if (!isAuiView(cls)) return null;
					var ctor = cls.constructor;
					if (ctor == null) return null;
					switch (Context.follow(ctor.get().type)) {
						case TFun(args, _): return [for (a in args) a.t];
						case _: return null;
					}
				case _: return null;
			}
		} catch (_:Dynamic) {
			return null;
		}
	}

	/** A view aui ships, or a subclass of one. **/
	static function isAuiView(cls:haxe.macro.Type.ClassType):Bool {
		var current = cls;
		while (current != null) {
			if (current.pack.join(".") == "aui.ui") return true;
			current = current.superClass == null ? null : current.superClass.t.get();
		}
		return false;
	}

	/**
		Wrap every construction. Decide nothing.

		This runs inside `@:build`, and that is the whole reason it decides
		nothing: resolving a view's type here types `aui.View`, whose
		`modifierChain.push` needs `Array` -- and on the **jvm** target the java
		externs are not registered yet, so `java.NativeArray has no field
		length` comes back from a standard library file naming none of our code.
		The build fails, and nothing in the message points here.

		`aui.ui.Text` resolves perfectly a moment later, while `body()` itself is
		being typed. So the decision moves there: each `new` is wrapped in a call
		to `live`, which is an expression macro and therefore expands at exactly
		that later moment.

		Anything that is not a view is wrapped too, and `live` hands it straight
		back. Judging here would mean resolving the type here, which is the one
		thing this pass exists to avoid.
	**/
	static function wrap(e:Expr):Expr {
		var mapped = e.map(wrap);
		return switch (mapped.expr) {
			case ENew(_, args) if (args.length > 0):
				macro @:pos(e.pos) aui.macros.LiveProps.live($mapped);
			case _:
				mapped;
		};
	}

	/**
		Decide, now that the types can be asked for.

		The arguments arrive already wrapped -- `wrap` walks children first --
		so this looks at one construction and never recurses.
	**/
	static function deferOne(e:Expr):Expr {
		return switch (e.expr) {
			case ENew(tp, args) if (args.length > 0):
				var types = ctorArgTypes(tp, e.pos);
				if (types == null || types.length < args.length) {
					e;
				} else {
					// A container keeps its identity: never re-run its constructor.
					var container = false;
					for (t in types) if (isViewish(t)) container = true;
					if (container) {
						e;
					} else {
						var neutral = [];
						var deferred = false;
						for (i in 0...args.length) {
							if (isDeferrableValue(types[i]) && !isConstant(args[i])) {
								neutral.push(neutralFor(types[i]));
								deferred = true;
							} else {
								neutral.push(args[i]);
							}
						}
						if (!deferred) {
							e;
						} else {
							var placeholder = {expr: ENew(tp, neutral), pos: e.pos};
							macro @:pos(e.pos) {
								var __live = $placeholder;
								__live.liveBuild = function() return $e;
								__live;
							};
						}
					}
				}
			case _:
				e;
		};
	}

	/** Rewrite `body()` and every method declared to return a `View`. **/
	public static function apply(fields:Array<Field>):Array<Field> {
		// Nothing to defer on the static path: the generator reads `body()` at
		// compile time, and a thunk is exactly what it cannot translate.
		if (RenderPath.isStatic()) return fields;

		for (field in fields) {
			switch (field.kind) {
				case FFun(fn) if (fn.expr != null):
					if (field.name != "body" && !returnsView(fn.ret)) continue;
					fn.expr = wrap(fn.expr);
				case _:
			}
		}
		return fields;
	}

	static function returnsView(ret:Null<ComplexType>):Bool {
		return switch (ret) {
			case TPath(p): p.name == "View";
			case _: false;
		};
	}
	#end

	/**
		One construction, judged at the moment it is typed.

		Declared outside the `#if macro` block on purpose: the call `wrap`
		emitted lives in ordinary application code, so the compiler has to find
		this field while typing that code. A macro function's *body* is only
		ever compiled in macro context, which is why it may call the helpers
		above.

		This is the second half of the split described on `wrap`. Everything it
		does used to happen during `@:build`, where asking for a view's type
		brought the java standard library down with it.
	**/
	public static macro function live(e:haxe.macro.Expr):haxe.macro.Expr {
		return deferOne(e);
	}
}
