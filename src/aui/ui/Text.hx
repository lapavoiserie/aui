package aui.ui;

import aui.View;

class Text extends View {
	public var content:String;
	public var composeExpression:Null<String>;

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
