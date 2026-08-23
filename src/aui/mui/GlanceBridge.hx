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
	the app shows. When nothing is running, the host constructs one — and what
	that instance is born with is now the application's own choice.

	This used to say that persisting state across process death was the
	application's business and not this bridge's. True, and useless: the
	application had no way of doing it. `@:state(durable)` is that way. A cell
	declared durable is constructed from the device store, so an instance built
	here for a widget refresh starts where the last one left off instead of at
	the application's initial state. An ordinary cell still starts at its
	default, which stays the right answer for anything not worth keeping.

	Still not this bridge's business — but no longer nobody's.
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

	/**
		Sample the application this bridge last sampled, or `null` if it has
		sampled none yet.

		The one between `sampleLive` and `sampleOf`: the Activity is gone but
		the process is not, so there is no live root to ask and yet there is a
		perfectly good application holding the state the user last saw.
		Constructing a second one instead would answer with the *initial*
		state and quietly throw away a tap that had just landed.
	**/
	public static function sampleAgain():Null<String> {
		var mine = _sampled;
		if (mine == null) return null;
		return sampleOf(mine);
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

		## Sample before you invoke

		The tap arrives in a process that may have started for this very
		callback, with an empty table — the launcher kept the picture, we kept
		nothing. Sampling first rebuilds the table, and the id still resolves,
		because ids are keyed by PLACE: walking the same tree hands the same
		button the same id. That is the property the first interactive
		Companion paid for, collected here at a different distance.

		It holds while the tree keeps its shape. A tree whose shape changed
		between the launcher's picture and the tap — a list one item shorter —
		names something else or nothing, and the honest answer is the word
		`ActionTable` already prints.

		What would close that is persisting the **id → place** map beside the
		picture and resolving a cold tap by place: `ActionTable` keys every
		action by `"path#prop"`, and a button that did not move keeps that key
		even when its neighbours vanish. The table itself cannot be persisted
		— it maps ids to CLOSURES — so it is the map that would be stored, not
		the table. Not done.
	**/
	public static function invoke(id:Int, arg:String):Void {
		if (_table == null) return;
		_table.invoke(id, arg);
	}

	/** The surface's own effect, or `null` while nothing is followed. **/
	static var _following:Null<rui.Signal.Effect> = null;

	/**
		Begin following the Glance declaration, so a write refreshes the widget.

		The same move `sui` makes and `cafos.nui.NuiProjector` has made since it
		shipped: the effect evaluates the declaration's thunk, `rui` records the
		cells it read, and a write to any of them re-runs it. Nobody has to
		remember to call `Resample.request` — a `-` button that never called it
		used to leave the widget showing a number nobody had.

		**Why the sample here is thrown away.** Android's widget is a *pull*:
		`GlanceHost.requestUpdate()` nudges the host, and the host then calls
		`AuiGlance.push`, which samples for itself. So this effect samples only
		to be subscribed to what the tree reads, and the result is discarded.
		One extra walk of a small tree per change, in exchange for the host
		keeping ownership of when it draws — which is the contract a snapshot
		surface is under.

		Idempotent. Started with the Primary root and dropped with it, so a
		rotation that releases the application does not leave an effect holding
		the old instance alive.
	**/
	public static function follow(app:aui.mui.App):Void {
		if (_following != null) return;
		if (pickGlance(app.surfaces()) == null) return;
		_following = new rui.Signal.Effect(() -> {
			sampleOf(app);
			aui.glance.GlanceHost.requestUpdate();
		});
	}

	/** Stop following, and release what the effect held. **/
	public static function unfollow():Void {
		var e = _following;
		_following = null;
		if (e != null) e.dispose();
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
