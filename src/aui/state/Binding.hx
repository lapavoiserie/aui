package aui.state;

/**
    Two-way binding between a state and a control.
    Used by TextField, Toggle, Slider, etc. for read/write access.

    Usage:
        var name = new State<String>("", "name");
        var binding = Binding.fromState(name);
**/
class Binding<T> {
    public var getter:() -> T;
    public var setter:T -> Void;

    public function new(getter:() -> T, setter:T -> Void) {
        this.getter = getter;
        this.setter = setter;
    }

    public function get():T {
        return getter();
    }

    public function set(v:T):Void {
        setter(v);
    }

    /** Create a two-way binding from a State<T>. **/
    public static function fromState<T>(state:State<T>):Binding<T> {
        return new Binding<T>(
            () -> state.get(),
            (v) -> state.set(v)
        );
    }
}
