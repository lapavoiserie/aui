package aui.ui;

import aui.View;

@:node("Text")
class Text extends View {
	public var content:String;

	/**
		What this text actually says, templates resolved.

		`stateTemplate` carries `{name}` placeholders standing for named cells,
		and until now only `aui.nui.Describe` knew to expand them. Read from
		here instead: it is a fact about the text, not about who is asking.
	**/
	@:prop("text") public var text(get, never):String;

	function get_text():String {
		if (stateTemplate == null) return content == null ? "" : content;
		return ~/\{([^}]+)\}/g.map(stateTemplate, function(r) {
			var cell:Dynamic = aui.state.State.getByName(r.matched(1));
			return cell == null ? r.matched(0) : Std.string(cell.get());
		});
	}
	public var composeExpression:Null<String>;

	/**
		How the canon says this text is set (`nui.TextStyle`): a scale, a family
		the application ships, a weight, italic, and digits of one width.

		Props rather than modifiers, because a prop is what crosses a wire
		intact and what a renderer can switch on — see nui's node model. The
		scale is kept here as well as pushed as a `Font` modifier, which is what
		the static generator reads off the typed AST.
	**/
	@:prop public var scale:Null<nui.Scale>;

	@:prop public var family:Null<String>;

	@:prop public var weight:Null<Int>;

	@:prop("italic") public var italicFace:Null<Bool>;

	@:prop public var numbers:Null<nui.Numbers>;

	/**
		The template as written, `"compteur : {count}"`.

		`composeExpression` is that template already rewritten for Kotlin, which
		only the static generator can use. The dynamic renderer has no Kotlin to
		interpolate into — it needs the names, so it can read them from the state
		registry at runtime. Keeping both is not duplication: one is a source,
		the other a translation of it for one consumer.
	**/
	public var stateTemplate:Null<String>;

	public function new(text:String) {
		super();
		this.viewType = "Text";
		this.content = text;
	}

	/** Say how it is set; Compose decides what it can do with it. **/
	public function styled(?scale:nui.Scale, ?family:String, ?weight:Int, ?italic:Bool, ?tabular:nui.Numbers):Text {
		// In the properties map as well as the fields, under the canon's own
		// names: the renderer asks the bridge for "italic", and this class's
		// field is `italicFace` because `italic()` is a modifier on every view.
		// A field whose name does not match is a prop the renderer never finds.
		if (scale != null) {
			// `nui.Scale` normalised it on the way in, whatever said it.
			this.scale = scale;
			properties.set("scale", (this.scale : String));
		}
		if (family != null && family != "") {
			this.family = family;
			properties.set("family", family);
		}
		if (weight != null) {
			this.weight = nui.TextStyle.weightOf(weight);
			properties.set("weight", this.weight);
		}
		if (italic != null) {
			this.italicFace = italic;
			properties.set("italic", italic);
		}
		if (tabular) {
			this.numbers = tabular;
			properties.set("numbers", (this.numbers : Null<String>));
		}
		return this;
	}

	public static function withState(template:String):Text {
		var text = new Text("");
		// Convert {varName} placeholders to Compose state references
		var composeExpr = ~/\{([^}]+)\}/g.map(template, function(r) {
			var matched = r.matched(1);
			return "$" + "{appState." + matched + "}";
		});
		text.composeExpression = composeExpr;
		text.stateTemplate = template;
		return text;
	}
}
