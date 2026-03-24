package aui.state;

class State<T> {
	public var value:T;
	public var name:String;

	static var _registry:Map<String, Dynamic> = new Map();

	public function new(initialValue:T, name:String) {
		this.value = initialValue;
		this.name = name;
		_registry.set(name, this);
	}

	public function get():T {
		return value;
	}

	public function set(newValue:T):Void {
		value = newValue;
	}

	// Action builders
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
