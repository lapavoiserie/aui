package aui.macros;

#if macro
import haxe.macro.Context;
#end

/**
	Which of the two renderers a build targets — asked here, and nowhere else.

	`aui` has always had two ways to put a view on screen:

	- **dynamic** — the app runs, `body()` builds a tree, and `DynamicComposable.kt`
	  walks it through `nui`'s pull contract. Compose sees the Haxe reads, so a
	  write recomposes the node that read it.
	- **static** — the generator reads `body()` at compile time and emits Kotlin
	  ahead of time. Nothing of the view survives to runtime.

	The static path used to be the default and the dynamic one the opt-in
	(`-D aui_dynamic`). That is now inverted: **dynamic is the path**, and the
	static transpiler is kept, unmaintained, behind `-D aui_static` so a build
	that depended on it still has somewhere to go.

	Why it was set aside rather than kept in parallel: it cannot render a
	`ViewComponent` (it would need a composable carrying the component's own
	state), and it has no fine-grained recomposition to offer — the reason the
	dynamic path exists at all. Every feature added since is dynamic-only, so
	holding the two at parity meant paying for the static one twice.

	`-D aui_dynamic` is still accepted, and now says what is already true.
**/
class RenderPath {
	/** Opt back in to the decommissioned static transpiler. **/
	public static inline var STATIC_DEFINE = "aui_static";

	/** What every build used to pass. A no-op now: the default says it. **/
	public static inline var DYNAMIC_DEFINE = "aui_dynamic";

	#if macro
	static var _isStatic:Null<Bool> = null;

	/** True when this build asked for the decommissioned static transpiler. **/
	public static function isStatic():Bool {
		if (_isStatic == null) _isStatic = resolve();
		return _isStatic;
	}

	/** True for every build that did not. **/
	public static function isDynamic():Bool {
		return !isStatic();
	}

	/**
		Resolved once. The deprecation warning belongs to the build, not to each
		of the eight places that branch on the answer.
	**/
	static function resolve():Bool {
		if (!Context.defined(STATIC_DEFINE)) return false;

		// Both defines at once is not a preference to guess at: one of them is
		// left over, and picking either silently would build something the
		// developer did not ask for.
		if (Context.defined(DYNAMIC_DEFINE)) {
			Context.error('[AUI] -D $STATIC_DEFINE and -D $DYNAMIC_DEFINE contradict each other.\n'
				+ '  Drop -D $STATIC_DEFINE for the dynamic renderer, which is the default,\n'
				+ '  or drop -D $DYNAMIC_DEFINE if the static path is really what you want.',
				Context.currentPos());
		}

		Context.warning('[AUI] the static Compose path is decommissioned and unmaintained.\n'
			+ '  It does not support ViewComponent nor fine-grained recomposition.\n'
			+ '  Drop -D $STATIC_DEFINE to use the dynamic renderer.',
			Context.currentPos());
		return true;
	}
	#end
}
