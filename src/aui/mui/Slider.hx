package aui.mui;


/**
	`aui`'s conformance for `mui.ui.Slider`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
class Slider extends aui.ui.Slider {
    public function new(state:SliderBinding, min:Float = 0.0, max:Float = 1.0) {
        super(state.unwrap(), min, max);
    }
}
