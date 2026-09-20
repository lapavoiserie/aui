package aui.nui;

import aui.View;

/**
	Put the canon's decorations on one of this backend's own views.

	`mui`'s markup builds `aui` controls directly (`nui.macros.Construct`), so
	its decorations arrive as the same `Array<nui.Modifier>` the node path
	would have carried — same names, same order, because the order IS the
	semantics.

	## What this backend cannot honour, said rather than dropped

	The canon's rule is that a backend honours what it can and skips the rest.
	Skipping in silence is how a decoration comes to be written, carried, and
	drawn nowhere, so each one says so once.

	- **`border`** — `ViewModifier.Border` takes a `ColorValue`, and
	  `aui.nui.Colors` converts only the other way (`say`). A role has no door
	  into it here.
	- **`flex`** — Compose shares leftover space by weight, and this backend
	  exposes `fillMaxWidth`/`fillMaxHeight` rather than a share. Not the same
	  thing, so not mapped to it.
**/
class Decorate {
	public static function apply(view:View, modifiers:Array<nui.Modifier>):View {
		if (view == null || modifiers == null) return view;
		for (m in modifiers) {
			if (m == null) continue;
			var f = m.floats;
			var s = m.strings;
			switch (m.type) {
				case nui.Modifiers.PADDING:
					// One float is every edge. Compose has no four-edge
					// modifier here, so the first is taken and the rest are
					// what this backend cannot say.
					if (f != null && f.length > 0) view.padding(f[0]);

				case nui.Modifiers.BACKGROUND_COLOR:
					if (s != null && s.length > 0) view.backgroundSaid(s[0]);

				case nui.Modifiers.FOREGROUND_COLOR:
					if (s != null && s.length > 0) view.foregroundSaid(s[0]);

				case nui.Modifiers.OPACITY:
					if (f != null && f.length > 0) view.opacity(f[0]);

				case nui.Modifiers.CLIP:
					view.clip();

				case nui.Modifiers.WIDTH:
					if (f != null && f.length > 0) view.frame(f[0], null);

				case nui.Modifiers.HEIGHT:
					if (f != null && f.length > 0) view.frame(null, f[0]);

				case other:
					// Unreachable from markup: `Vocabulary.honoured` lists what
					// this can draw, and `mui`'s markup refuses anything else by
					// name while compiling. Reaching it means those two lists
					// disagree, which is a bug and not a decoration to skip.
					throw "aui.nui.Decorate: asked for \"" + other + "\", which "
						+ "Vocabulary.honoured does not list";
			}
		}
		return view;
	}
}
