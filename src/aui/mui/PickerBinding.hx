package aui.mui;


/**
	`aui`'s conformance for `mui.ui.PickerBinding`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. The same shape as
	`ToggleBinding`, over the index of the option chosen.
**/
abstract PickerBinding(aui.state.State<Int>) {
    public inline function new(v:aui.state.State<Int>) this = v;

    @:from static inline function fromState(s:aui.state.State<Int>):PickerBinding
        return new PickerBinding(s);

    public inline function unwrap():aui.state.State<Int> return this;
}
