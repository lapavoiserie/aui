package aui.nui;

import aui.modifiers.ViewModifier.ColorValue;
import nui.Color as Wire;
import nui.Role;

/**
	A colour said in `nui`'s words, whatever an application wrote.

	`aui` keeps its chain as `ColorValue` — `Gray`, `Custom(…)`, `Accent` — and two
	consumers read it: the Compose bridge, which hands modifiers to Kotlin, and
	`aui.nui.Describe`, which puts them on the wire. Both used to get
	`Std.string` of the enum VALUE, so Kotlin saw `Gray` and the wire saw
	`Rgb(200,50,60)`. Neither is a colour anybody agreed on.

	The word goes into the chain instead, so both consumers get the same thing
	and it is the thing the canon names.

	## A named colour becomes components

	`nui.Color` carries roles and components, and **not** names: a name resolves
	to nothing per-platform, and carrying it would make it look semantic when it
	is not. So `ColorValue.Gray` leaves here as `#808080` — the conventional
	grey — which is the same call `cui` makes for its sixteen, in the same
	direction, for the same reason: the wire has no way to say "the grey this
	toolkit uses".

	`Primary`, `Secondary` and `Accent` are the three that ARE roles, and they
	cross as `role:accent`. Compose resolves them against `MaterialTheme`, which
	is where a Material accent actually lives.
**/
class Colors {
	/** A `ColorValue` in the canon's words, or null when it says nothing. **/
	public static function say(colour:Null<ColorValue>):Null<Wire> {
		if (colour == null) return null;
		return switch (colour) {
			// The three that are about a purpose rather than a hue.
			case Primary | Accent: Wire.role(Role.Accent);
			case Secondary: Wire.role(Role.Muted);

			case Custom(hex): Wire.hex(hex);

			// Conventional components, because a name cannot cross.
			case Red: Wire.rgb(220, 38, 38);
			case Orange: Wire.rgb(234, 88, 12);
			case Yellow: Wire.rgb(202, 138, 4);
			case Green: Wire.rgb(22, 163, 74);
			case Blue: Wire.rgb(37, 99, 235);
			case Purple: Wire.rgb(124, 58, 237);
			case Pink: Wire.rgb(219, 39, 119);
			case White: Wire.rgb(255, 255, 255);
			case Black: Wire.rgb(0, 0, 0);
			case Gray: Wire.rgb(128, 128, 128);
			// Nothing at all rather than a transparent black: a modifier
			// asking for nothing is no modifier.
			case Transparent: null;
		}
	}
}
