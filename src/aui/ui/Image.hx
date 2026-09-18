package aui.ui;

import aui.View;

/**
	A picture: nui's canonical `Image`, drawn by `AuiImage`
	(`runtime/AuiPictures.kt`).

	`src` names where the picture comes from by its scheme -- `asset:`, `data:`,
	`file:`, `https:` -- and `alt` is what stands in its place when it cannot be
	drawn, and what a screen reader says. See nui's node model.
**/
@:node("Image")
@:bag("src:String", "alt:String", "width:Float", "height:Float", "fit:String")
class Image extends View {
	public function new(src:String, ?alt:String, ?options:{?width:Float, ?height:Float, ?fit:String}) {
		super();
		this.viewType = "Image";
		properties.set("src", src == null ? "" : src);
		properties.set("alt", alt == null ? "" : alt);
		if (options != null) {
			if (options.width != null) properties.set("width", options.width);
			if (options.height != null) properties.set("height", options.height);
			if (options.fit != null) properties.set("fit", options.fit);
		}
	}
}
