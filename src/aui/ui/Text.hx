package aui.ui;

import aui.View;

class Text extends View {
	public var content:String;
	public var composeExpression:Null<String>;

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
		return text;
	}
}
