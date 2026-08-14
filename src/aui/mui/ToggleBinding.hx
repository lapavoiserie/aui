package aui.mui;


/**
	`aui`'s conformance for `mui.ui.ToggleBinding`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
abstract ToggleBinding(aui.state.State<Bool>) {
    public inline function new(v:aui.state.State<Bool>) this = v;

    @:from static inline function fromState(s:aui.state.State<Bool>):ToggleBinding
        return new ToggleBinding(s);

    public inline function unwrap():aui.state.State<Bool> return this;
}
