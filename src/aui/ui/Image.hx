package aui.ui;

import aui.View;

class Image extends View {
	public var resourceName:String;
	public var systemName:Null<String>;

	public function new(resourceName:String) {
		super();
		this.viewType = "Image";
		this.resourceName = resourceName;
	}

	public static function system(name:String):Image {
		var img = new Image("");
		img.systemName = name;
		img.viewType = "SystemImage";
		return img;
	}
}
