package aui.ui;

import aui.View;

/**
	An icon from the shared vocabulary (`nui.Icons`), drawn as its Material icon
	and tinted like text (`AuiIcons` in `runtime/AuiPictures.kt`). A name aui has
	no icon for draws its label, as text.
**/
@:node("Icon")
@:bag("name:String", "label:String")
class Icon extends View {
	public function new(name:String, ?label:String) {
		super();
		this.viewType = "Icon";
		properties.set("name", name);
		if (label != null && label != "") properties.set("label", label);
	}
}
