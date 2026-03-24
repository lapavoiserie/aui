package aui.ui;

import aui.View;

class Tab {
	public var title:String;
	public var icon:String;
	public var content:View;

	public function new(title:String, icon:String, content:View) {
		this.title = title;
		this.icon = icon;
		this.content = content;
	}
}
