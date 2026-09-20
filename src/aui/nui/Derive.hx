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
	/** Build `aui.nui.Derived`'s describers from what the controls declare. **/
	public static function build():Array<Field>
		return nui.macros.Derive.build(aui.nui.Vocabulary.DIALECT);

	#end
}
