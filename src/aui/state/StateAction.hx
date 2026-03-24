package aui.state;

enum StateAction {
	Increment(state:Dynamic, ?amount:Dynamic);
	Decrement(state:Dynamic, ?amount:Dynamic);
	SetValue(state:Dynamic, value:Dynamic);
	Toggle(state:Dynamic);
	Append(state:Dynamic, value:Dynamic);
	Animated(action:StateAction, curve:AnimationCurve);
}

enum AnimationCurve {
	Default;
	EaseIn;
	EaseOut;
	EaseInOut;
	Spring;
	Linear;
	Bouncy;
}
