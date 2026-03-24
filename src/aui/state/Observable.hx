package aui.state;

class Observable {
	var _changedProperties:Array<String> = [];

	public function new() {}

	public function notifyPropertyChanged(propertyName:String):Void {
		if (_changedProperties.indexOf(propertyName) == -1) {
			_changedProperties.push(propertyName);
		}
	}

	public function consumeChanges():Array<String> {
		var changes = _changedProperties.copy();
		_changedProperties = [];
		return changes;
	}
}
