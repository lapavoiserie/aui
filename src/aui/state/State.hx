package aui.state;

/**
	Reactive state cell shared between Haxe and Compose.

	Internally backed by a Compose `MutableState<T>` (created via the JVM/Kotlin
	`aui.state.StateBridge` runtime), so reads inside a `@Composable` are tracked
	and writes from anywhere — including pure Haxe JVM bytecode invoked by lifted
	closures from `Button("...", () -> { ... })` — trigger recomposition
	automatically.

	The public API is unchanged from the original (`.get()`, `.set(v)`, `.value`),
	so existing AUI examples and the StateAction builders keep working.
**/
class State<T> {
	// Opaque reference to a Compose MutableState<Any?> created by StateBridge.create().
	// Held as Dynamic so this Haxe class doesn't import any Compose types.
	var bridge:Dynamic;

	public var name:String;
	public var value(get, set):T;

	static var _registry:Map<String, Dynamic> = new Map();

	public function new(initialValue:T, name:String) {
		this.bridge = StateBridge.create(initialValue);
		this.name = name;
		_registry.set(name, this);
	}

	inline function get_value():T return (cast StateBridge.read(bridge):T);
	inline function set_value(v:T):T {
		StateBridge.write(bridge, v);
		return v;
	}

	public function get():T return (cast StateBridge.read(bridge):T);
	public function set(newValue:T):Void StateBridge.write(bridge, newValue);

	// Action builders — unchanged
	public function inc(?amount:Dynamic):StateAction {
		return StateAction.Increment(this, amount);
	}

	public function dec(?amount:Dynamic):StateAction {
		return StateAction.Decrement(this, amount);
	}

	public function setTo(val:Dynamic):StateAction {
		return StateAction.SetValue(this, val);
	}

	public function tog():StateAction {
		return StateAction.Toggle(this);
	}

	public function appendAction(val:Dynamic):StateAction {
		return StateAction.Append(this, val);
	}

	public static function getByName(name:String):Dynamic {
		return _registry.get(name);
	}
}
