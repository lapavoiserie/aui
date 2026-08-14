package aui.mui;


/**
	`aui`'s conformance for `mui.ui.SliderBinding`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
abstract SliderBinding(aui.state.State<Float>) {
    public inline function new(v:aui.state.State<Float>) this = v;

    @:from static inline function fromState(s:aui.state.State<Float>):SliderBinding
        return new SliderBinding(s);

    public inline function unwrap():aui.state.State<Float> return this;
}
