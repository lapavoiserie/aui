package aui.mui;

/**
	`aui`'s conformance for `mui.ui.Image`: the canonical picture, with mui's
	options.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`.
**/
class Image extends aui.ui.Image {
	public function new(src:String, alt:String, ?options:mui.ui.ImageOptions) {
		super(src, alt, options == null ? null : {width: options.width, height: options.height,
			fit: options.fit == null ? null : (options.fit : String)});
	}
}
