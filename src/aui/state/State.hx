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
class State<T> extends rui.state.State<T> {
	// Opaque reference to a Compose MutableState<Any?> created by StateBridge.create().
	// Held as Dynamic so this Haxe class doesn't import any Compose types.
	var bridge:Dynamic;

	// The remaining cross-surface global on this backend, named as such: one
	// flat map keyed by FIELD NAME, consumed by `ViewNodeBridge.resolveTemplate`
	// for `Text.withState("{count}")`. Two roots (or two App instances -- the
	// rotation bug already builds a second one) declaring the same name
	// silently repoint the entry to the newest cell. The scoped fix is shared
	// across backends (wui carries the same map) and waits on the sui
	// invalidation-key decision: whatever joins a surface id to a cell name
	// there is the shape this key takes too.
	static var _registry:Map<String, Dynamic> = new Map();

	public function new(initialValue:T, name:String) {
		super(initialValue, name);
		this.bridge = StateBridge.create(initialValue);
		_registry.set(name, this);
	}

	// `value` must go through get()/set() so a read is observed by Compose and
	// a write reaches both sides. The inherited accessors read the signal only.
	override function get_value():T return get();

	/**
		Read. Two things happen and both matter:

		- `super.get()` reads through the `rui` signal, so a read inside a `rui`
		  effect registers the dependency — this is what the shared core buys.
		- the returned value comes from the Compose `MutableState`, so a read
		  inside a `@Composable` is tracked by Compose and drives recomposition.

		The two stay in step because every write goes through `set()`.
	**/
	override public function get():T {
		super.get();
		return (cast StateBridge.read(bridge):T);
	}

	/**
		Write. Updates the shared core (so `rui` effects re-run) and mirrors into
		the Compose `MutableState`, which remains what actually drives
		recomposition. The mirror is unconditional: Compose applies its own
		structural-equality policy, and the generated Kotlin writes back through
		this same path, so short-circuiting here would risk desynchronising the
		two sides.
	**/
	override public function set(newValue:T):Void {
		super.set(newValue);
		StateBridge.write(bridge, newValue);
	}

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
