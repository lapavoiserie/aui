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
	static var _follower:Null<mui.surface.Follow.Follower> = null;
	static var _followed:Null<aui.mui.App> = null;

	/**
		Begin following this application's Glance declaration.

		The mechanism is `mui.surface.Follow`, shared with sui's widget and the
		Companion projection. What stays here is Android's own shape: its widget
		is a **pull**, so the callback throws the picture away and nudges the
		host, which then asks for its own sample through `sample()` below. One
		extra walk of a small tree per change, in exchange for the host keeping
		ownership of when it draws.

		Idempotent for the SAME application, and re-bound for a different one.
		`setApp` legitimately runs again with a new instance when the Activity
		is recreated without the app being released; a guard on "already
		following" would leave the effect watching the instance that is no
		longer on screen, and the widget would stop following with nothing to
		see. Benjamin found exactly that by tapping.
	**/
	public static function follow(app:aui.mui.App):Void {
		if (_followed == app) return;
		unfollow();
		var decl = pickGlance(app.surfaces());
		if (decl == null) return;
		_followed = app;
		_follower = mui.surface.Follow.surface(decl, _ -> aui.glance.GlanceHost.requestUpdate());
	}

	/** Stop following, and release what the effect held. **/
	public static function unfollow():Void {
		var f = _follower;
		_follower = null;
		_followed = null;
		if (f != null) f.dispose();
	}

	/**
		The picture, for a host that asks.

		Called from the generated Kotlin when Glance draws. Answers from the
		live follower when there is one; otherwise constructs nothing and says
		so, and the caller falls back to building an application of its own.
	**/
	public static function sampleLive():Null<String> {
		var f = _follower;
		return f == null ? null : f.sampleNow();
	}

	/** Kept for the generated Kotlin's fallback chain, which asks three ways
		before giving up. Both now answer from the same follower. **/
	public static function sampleAgain():Null<String> {
		return sampleLive();
	}

	/**
		Sample an application the host built for itself, with no live one
		around. Follows it too: a process that woke for a widget refresh should
		keep the picture current for as long as it lives.
	**/
	public static function sampleOf(app:Dynamic):Null<String> {
		var mine = Std.downcast(app, aui.mui.App);
		if (mine == null) return null;
		follow(mine);
		return sampleLive();
	}

	/**
		Run what a widget tap names.

		`arg` carries the control's live value for the callback shapes that have
		one, and is ignored by the rest; an id the table has retired is answered
		with a word, never a crash, because it may legitimately name a control
		that left the tree between the launcher's picture and the user's finger.

		The tap arrives in a process that may have started for this very
		callback. The generated Kotlin samples before invoking, which is what
		starts the follower and builds its table — and the id still resolves,
		because ids are keyed by PLACE.
	**/
	public static function invoke(id:Int, arg:String):Void {
		var f = _follower;
		if (f != null) f.invoke(id, arg);
	}

	/**
		One cover per app, one widget per declaration — the same rule `qui`
		applies to the Sailfish cover: the declaration whose id is the role's
		default if there is one, else the first declared. Stated rather than
		left to iteration order, which is not identity.
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
