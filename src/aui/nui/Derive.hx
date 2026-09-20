package aui.nui;

#if macro
import haxe.macro.Expr.Field;
#end

/**
	Describing, written by `aui`'s declarations rather than by hand.

	Only that direction: `aui` draws with Compose, in Kotlin, so nothing here
	ever makes a control out of a node. `BUILDERS` is therefore empty and
	`DESCRIBERS` is the whole of it.

	See `nui.macros.Derive` for the shared part, and `aui.nui.Vocabulary` for
	the two things that are `aui`'s own: the bag its props live in, and the fact
	that it only describes.
**/
class Derive {
	#if macro
	/**
		Build `aui.nui.Derived`'s describers from what the controls declare.

		**Without `cells`**, and that is the one thing this dialect changes.
		`nui.macros.Derive` reads it as "this backend BUILDS controls from
		nodes at runtime" and generates builders; `aui` does not -- it draws
		with Compose and reads a received tree natively, which is why
		`BUILDERS` is empty here and `DESCRIBERS` is the whole of it.

		`Vocabulary.DIALECT` names `cells` all the same, for
		`nui.macros.Construct`: that builds controls while COMPILING, from
		markup, where there is no node and nothing to read back. The two
		readers want different answers to the same question, so the difference
		is said here rather than by keeping two dialects that drift.
	**/
	public static function build():Array<Field> {
		var d = aui.nui.Vocabulary.DIALECT;
		return nui.macros.Derive.build({
			pack: d.pack, view: d.view, bag: d.bag,
			appendChildren: d.appendChildren,
		});
	}
	#end
}
