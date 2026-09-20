package aui.nui;

#if macro
import haxe.macro.Context;
import nui.macros.Declarations;
import nui.macros.Declarations.Action;
import nui.macros.Declarations.Dialect;
import nui.macros.Declarations.Prop;
#end

/**
	What `aui` describes, read from the controls themselves.

	The reading lives in `nui.macros.Declarations`, shared by every backend.
	Two things are `aui`'s own beyond which controls and what a view is:

	- it has a **bag**. Every control writes into a `Map<String, Dynamic>` that
	  the Kotlin renderer reads by name, so `Image` and `Icon` have no typed
	  field for a prop at all. `@:bag("src:String", …)` says what those carry,
	  because the map cannot.
	- it **describes only**. Its renderer is Compose, in Kotlin, so there is no
	  builder to generate and no cell to make — which is also why a read-only
	  property is legitimate here.
**/
class Vocabulary {
	/** Kept so the class exists outside macro context. **/
	public static var DUMMY(default, never):Int = 0;

	#if macro
	public static final DIALECT:Dialect = {
		pack: "aui.ui",
		view: "aui.View",
		bag: "properties",
		// For `nui.macros.Construct`, which builds these controls from markup
		// while compiling. Nothing needed it before: this backend describes
		// and never builds a view out of a node, so no runtime builder was
		// ever generated.
		cells: "aui.nui.Cells",
		appendChildren: "aui.nui.Describe.appendChildren",
	};

	public static function types():Map<String, String>
		return Declarations.types(DIALECT);

	public static function propsFor(type:String):Array<Prop>
		return Declarations.propsFor(DIALECT, type);

	public static function actionsFor(type:String):Array<Action>
		return Declarations.actionsFor(DIALECT, type);

	public static function verify():Int
		return Declarations.verify(DIALECT);

	/** Hand `mui` the schema `ui(<VStack>…)` checks a tag against. **/
	#if (mui || mui_backend)
	public static function registerWithMui():Void {
		mui.macros.Backend.register({
			knows: type -> types().exists(type),
			keysOf: keysOf,
			requiredOf: requiredOf,
			kindOf: attributeKind,
			types: () -> [for (type in types().keys()) type],
			// Markup becomes `new aui.ui.VStack(...)` rather than a node --
			// which this backend could not have read back anyway: it
			// describes, and never builds a view out of one.
			//
			// No `decorate` yet. The others hand their chain to the table
			// their NodeRenderer already reads; `aui` has no such table --
			// modifiers are a chain on the view, translated by
			// `ComposeGenerator`. Markup says so by name rather than dropping
			// a decoration silently.
			//
			// Behind `-D mui_views` while the two shapes coexist.
			#if mui_views
			viewOf: (tag, given, children, pos) ->
				nui.macros.Construct.expr(DIALECT, tag, given, children, pos),
			#end
		});
	}
	#else
	public static function registerWithMui():Void {
		Context.error("aui.nui.Vocabulary.registerWithMui() was called, but `mui` is "
			+ "not visible from this build.\n"
			+ "  Add `-lib mui`, or `-D mui_backend=aui` if mui is on the class path "
			+ "some other way.", Context.currentPos());
	}
	#end

	/** Every attribute a tag accepts: its properties and its acts. **/
	public static function keysOf(type:String):Array<String> {
		var out = [for (p in propsFor(type)) p.name];
		for (p in propsFor(type)) if (p.callback != null) out.push(p.callback);
		for (a in actionsFor(type)) out.push(a.name);
		return out;
	}

	/** The attributes a tag cannot be written without. **/
	public static function requiredOf(type:String):Array<String>
		return [for (p in propsFor(type)) if (p.argument != null && !p.optional) p.name];

	/** Which `nui.PropValue` constructor an attribute takes. `null` if unknown. **/
	public static function attributeKind(type:String, key:String):Null<String> {
		for (p in propsFor(type)) {
			if (p.name == key) return "K" + p.kind;
			if (p.callback == key) return "KCallback" + p.kind;
		}
		for (a in actionsFor(type))
			if (a.name == key) return a.carries == null ? "KCallback" : "KCallback" + a.carries;
		return null;
	}
	#end
}
