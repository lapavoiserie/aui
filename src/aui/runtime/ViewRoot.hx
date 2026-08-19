package aui.runtime;

import aui.View;
import aui.nui.ViewSource;

/**
	One render root: the app that builds it, the tree it last built, and the
	`ViewSource` that walks it.

	This is aui's shape of the per-surface record the surfaces work converges
	on ({driver, effect, lifetime}): the source is the driver, the effect is
	Compose's own snapshot scope — `rebuild()` runs inside composition, so the
	reads are recorded there — and the lifetime is the app's, bracketed around
	`body()`.

	`ViewNodeBridge`'s statics route to the Primary instance of this, because
	Kotlin calls statics by name and an interface has no static methods. A
	second root is therefore a `new ViewRoot(app)` plus a composable reading
	through it — not a refactor of the bridge: the node accessors already take
	the node they are asked about, so they are root-agnostic, and only
	"rebuild" and "which root" are per-root, which is exactly what this class
	holds.
**/
@:keep
class ViewRoot {
	public var app(default, null):Dynamic;
	public var root(default, null):View;
	public var source(default, null):ViewSource;

	public function new(app:Dynamic) {
		this.app = app;
		this.root = null;
		// A reader always exists: its accessors already answer "" / 0 / false
		// for a null node, so a query before the first rebuild is a shrug,
		// not a crash.
		this.source = new ViewSource(null);
	}

	/** Re-evaluate the tree by re-running the app's `body()`. **/
	public function rebuild():Void {
		if (app == null) return;
		app.lifetime.beginPass();
		root = app.body();
		source = new ViewSource(root);
		// Force the lazy parts inside this scope: see ViewSource.classify.
		source.classify();
		// After classify: that is where the lazy parts were forced, so it is
		// where a component has finished declaring.
		app.lifetime.endPass();
	}

	/** The root node as Kotlin holds it: an opaque handle. **/
	public function rootHandle():Dynamic {
		return root;
	}
}
