package aui.ui;

import aui.View;

class Card extends View {
	public function new(content:Array<View>) {
		super();
		this.viewType = "Card";
		this.children = content;
	}
}
