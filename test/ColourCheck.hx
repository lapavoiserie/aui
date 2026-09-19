import aui.modifiers.ViewModifier.ColorValue;

/**
	What a colour says on the way out.

	`aui` kept its chain as `ColorValue`, and two consumers read it: the Compose
	bridge and the describer. Both used to get `Std.string` of the enum VALUE,
	so Kotlin saw `Gray` and the wire saw `Custom(#c8323c)` -- neither a colour
	anybody agreed on. The canon's word goes into the chain instead.
**/
class ColourCheck {
	static var failures = 0;

	static function check(what:String, ok:Bool, ?extra:Dynamic):Void {
		Sys.println((ok ? "ok   " : "FAIL ") + what + (ok || extra == null ? "" : " — " + extra));
		if (!ok) failures++;
	}

	static function said(v:aui.View):String {
		var n = aui.nui.Describe.describe(v);
		return n.modifiers.length == 0 ? "(rien)" : n.modifiers[0].strings[0];
	}

	static function main() {
		// The three that are about a purpose cross as roles; Compose resolves
		// them against MaterialTheme, which is where a Material accent lives.
		check("an accent crosses as a role", said(new aui.ui.Text("x").background(Accent)) == "role:accent",
			said(new aui.ui.Text("x").background(Accent)));
		check("and so does the secondary, as muted",
			said(new aui.ui.Text("x").background(Secondary)) == "role:muted");

		// A name cannot resolve to anything per-platform, so it leaves as
		// components -- the same call cui makes for its sixteen.
		check("a named colour leaves as components",
			said(new aui.ui.Text("x").background(Gray)) == "#808080",
			said(new aui.ui.Text("x").background(Gray)));
		check("and a custom hex as itself",
			said(new aui.ui.Text("x").background(Custom("#C8323C"))) == "#c8323c");

		// A modifier asking for nothing is no modifier.
		check("transparent adds nothing at all",
			said(new aui.ui.Text("x").background(Transparent)) == "(rien)");

		// And an application may say a role outright.
		check("a role said outright crosses as one",
			said(new aui.ui.Text("x").backgroundSaid(nui.Color.role(Danger))) == "role:danger");

		Sys.println(failures == 0 ? "\nall checks passed" : '\n$failures failed');
		Sys.exit(failures == 0 ? 0 : 1);
	}
}
