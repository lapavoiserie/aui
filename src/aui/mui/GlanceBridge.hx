package aui.mui;

import mui.surface.SurfaceDecl;
import mui.surface.SurfaceRole;
import nui.Snapshot;
import nui.Snapshot.ActionTable;

/**
	The `Glance` surface, sampled for an Android App Widget.

	## Why a snapshot and not a live tree

	This is the **snapshot-detached** corner of the surface model, and Android
	is what makes the corner necessary rather than merely possible. A widget
	does not live in our window: the launcher draws it, from `RemoteViews`
	built in our process when the system decides an update is due — not when
	our state changes. There is no effect to reconcile and nobody to reconcile
	it for; there is a moment, and a picture owed at that moment.

	So the surface is *sampled*: its content thunk runs once, the tree is
	described as `nui` nodes, and `nui.Snapshot.project` turns it into pure
	data. What crosses to Kotlin is a JSON string, which is the same shape a
	Companion frame carries over the network — one contract, two distances.

	## The table outlives the sample

	Callbacks cannot cross: a widget button lands in the launcher's process,
	and what comes back is an id. The `ActionTable` is therefore kept between
	samples, and ids are keyed by PLACE (`nui.Snapshot`), so the button in the
	same slot keeps its id across samples. A tap that arrives after a resample
	invokes the current closure rather than a hole — the property the first
	interactive Companion had to learn the hard way, inherited here for free.

	## Which app is sampled

	The live one when the Activity is up (the retained instance, since
	`aui.App.release`), so a widget refreshed while the app is open shows what
	the app shows. When nothing is running, the host constructs one: the
	widget then renders the application's initial state, honestly — persisting
	state across process death is the application's business, not this
	bridge's.
**/
@:keep
class GlanceBridge {
	// One table for the life of the process, on purpose: see the class doc.
	static var _table:Null<ActionTable> = null;

	// The app the last sample came from, so an action arriving later invokes
	// closures that write to the cells that sample read.
	static var _sampled:Null<aui.mui.App> = null;

	/**
		Sample the running application's Glance surface, or `null` when no
		application is running — the host then constructs one and calls
		`sampleOf`.
	**/
	public static function sampleLive():Null<String> {
		var root = aui.runtime.ViewNodeBridge.primary();
		if (root == null) return null;
		return sampleOf(root.app);
	}

	/** Sample this application's Glance surface as snapshot JSON, or `null`
		when it declares none. **/
	public static function sampleOf(app:Dynamic):Null<String> {
		var mine = Std.downcast(app, aui.mui.App);
		if (mine == null) return null;

		var decl = pickGlance(mine.surfaces());
		if (decl == null) return null;

		var content = switch (decl) {
			case Tree(_, _, c): c;
			case _: null;
		}
		if (content == null) return null;

		_sampled = mine;
		if (_table == null) _table = new ActionTable();
		var node = aui.nui.Describe.describe(content());
		return haxe.Json.stringify(Snapshot.project(node, _table));
	}

	/**
		Run what a widget tap names.

		`arg` carries the control's live value for the callback shapes that
		have one, and is ignored by the rest; an id the table has retired is
		answered with a word, never a crash, because it may legitimately name
		a control that left the tree between the launcher's picture and the
		user's finger.
	**/
	public static function invoke(id:Int, arg:String):Void {
		if (_table == null) return;
		_table.invoke(id, arg);
	}

	/**
		One cover per app, one widget per declaration — but the first slice
		hosts a single widget, so the choice is the same rule `qui` applies to
		the Sailfish cover: the declaration whose id is the role's default if
		there is one, else the first declared. Stated here rather than left to
		iteration order, which is not identity.
	**/
	static function pickGlance(decls:Array<SurfaceDecl>):Null<SurfaceDecl> {
		var first:Null<SurfaceDecl> = null;
		for (d in decls) switch (d) {
			case Tree(SurfaceRole.Glance, id, _):
				if (id == "glance") return d;
				if (first == null) first = d;
			case _:
		}
		return first;
	}
}
