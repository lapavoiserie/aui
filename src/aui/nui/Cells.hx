package aui.nui;

import aui.state.State;

/**
	A cell made out of what markup wrote and where its writes go.

	The one step in building a control from markup that a declaration cannot
	describe: what a two-way control takes is the backend's own idea. `aui`'s
	is an `aui.state.State` — which is also, on this backend and no other, a
	thing that **cannot simply be made twice**.

	## Why the place matters here and nowhere else

	`new State(value, name)` registers itself in a static map and creates a
	Compose `MutableState` through `StateBridge`. A view is rebuilt whenever
	the application's state changes, so a fresh cell per rebuild would grow
	that map for the life of the process and strand a Compose state on the
	Kotlin side each time.

	So a markup cell is kept under **where it was written** —
	`nui.macros.Construct` hands the place over, and the same place gives back
	the same cell. That is the rule node identity already follows across this
	family: the place, never the pointer. `pui`, `cui` and `qui` are handed the
	place too and ignore it, because their cells are ordinary objects collected
	with the view that held them.

	The name is prefixed `mui:` and carries a colon, which no Haxe field name
	can, so a markup cell can never collide with a `@:state` field in the
	registry `Text.withState("{count}")` reads.

	## Reseeding without reporting

	On the second build the cell already exists and the markup carries the
	current value again. It is written back only when it differs, and with the
	sink detached while it is: reporting a write the application itself just
	made would send it straight back where it came from.
**/
class Cells {
	public static function boolCellAt(site:String, value:Bool, tell:Bool->Void):State<Bool>
		return kept(site, value, tell);

	public static function intCellAt(site:String, value:Int, tell:Int->Void):State<Int>
		return kept(site, value, tell);

	public static function floatCellAt(site:String, value:Float, tell:Float->Void):State<Float>
		return kept(site, value, tell);

	public static function stringCellAt(site:String, value:String, tell:String->Void):State<String>
		return kept(site, value, tell);

	static function kept<T>(site:String, value:T, tell:T->Void):State<T> {
		var found:Dynamic = State.getByName(site);
		if (found == null) {
			var made:State<T> = new State(value, site);
			made.setPlatformSink(written -> if (tell != null) tell(written));
			return made;
		}

		var cell:State<T> = cast found;
		// The callback is a fresh closure on every build -- it closes over this
		// pass's `this` -- so the old one is replaced rather than kept.
		cell.setPlatformSink(null);
		if (cell.get() != value) cell.set(value);
		cell.setPlatformSink(written -> if (tell != null) tell(written));
		return cell;
	}
}
