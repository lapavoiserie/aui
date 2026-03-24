package aui;

import aui.modifiers.ViewModifier;

class View {
	public var viewType:String = "EmptyView";
	public var children:Array<View> = [];
	public var modifierChain:Array<ViewModifier> = [];
	public var properties:Map<String, Dynamic> = new Map();

	public function new() {}

	public function body():View {
		return this;
	}

	// --- Modifier methods (return this for chaining) ---

	// Layout
	public function padding(?value:Float):View {
		modifierChain.push(Padding(value));
		return this;
	}

	public function frame(?width:Float, ?height:Float, ?maxWidth:Float, ?maxHeight:Float, ?alignment:Alignment):View {
		modifierChain.push(Frame(width, height, maxWidth, maxHeight, alignment));
		return this;
	}

	public function offset(x:Float, y:Float):View {
		modifierChain.push(Offset(x, y));
		return this;
	}

	public function aspectRatio(?ratio:Float, ?contentMode:ContentMode):View {
		modifierChain.push(AspectRatio(ratio, contentMode));
		return this;
	}

	// Typography
	public function font(style:FontStyle):View {
		modifierChain.push(Font(style));
		return this;
	}

	public function bold():View {
		modifierChain.push(Bold);
		return this;
	}

	public function italic():View {
		modifierChain.push(Italic);
		return this;
	}

	public function lineLimit(lines:Int):View {
		modifierChain.push(LineLimit(lines));
		return this;
	}

	public function multilineTextAlignment(alignment:TextAlignment):View {
		modifierChain.push(MultilineTextAlignment(alignment));
		return this;
	}

	// Colors & Effects
	public function foregroundColor(color:ColorValue):View {
		modifierChain.push(ForegroundColor(color));
		return this;
	}

	public function background(color:ColorValue):View {
		modifierChain.push(Background(color));
		return this;
	}

	public function opacity(value:Float):View {
		modifierChain.push(Opacity(value));
		return this;
	}

	public function cornerRadius(radius:Float):View {
		modifierChain.push(CornerRadius(radius));
		return this;
	}

	public function clipShape(shape:ShapeType):View {
		modifierChain.push(ClipShape(shape));
		return this;
	}

	public function shadow(?color:ColorValue, ?radius:Float, ?x:Float, ?y:Float):View {
		modifierChain.push(Shadow(color, radius, x, y));
		return this;
	}

	public function blur(radius:Float):View {
		modifierChain.push(Blur(radius));
		return this;
	}

	public function scaleEffect(scale:Float):View {
		modifierChain.push(ScaleEffect(scale));
		return this;
	}

	public function rotationEffect(degrees:Float):View {
		modifierChain.push(RotationEffect(degrees));
		return this;
	}

	public function brightness(amount:Float):View {
		modifierChain.push(Brightness(amount));
		return this;
	}

	public function contrast(amount:Float):View {
		modifierChain.push(Contrast(amount));
		return this;
	}

	public function saturation(amount:Float):View {
		modifierChain.push(Saturation(amount));
		return this;
	}

	public function grayscale(amount:Float):View {
		modifierChain.push(Grayscale(amount));
		return this;
	}

	// Border & Overlay
	public function border(color:ColorValue, ?width:Float):View {
		modifierChain.push(Border(color, width));
		return this;
	}

	public function overlay(content:View):View {
		modifierChain.push(Overlay(content));
		return this;
	}

	// Interaction
	public function onTapGesture(action:() -> Void):View {
		modifierChain.push(OnTapGesture(action));
		return this;
	}

	public function onLongPressGesture(action:() -> Void):View {
		modifierChain.push(OnLongPressGesture(action));
		return this;
	}

	public function onAppear(action:() -> Void):View {
		modifierChain.push(OnAppear(action));
		return this;
	}

	public function onDisappear(action:() -> Void):View {
		modifierChain.push(OnDisappear(action));
		return this;
	}

	public function disabled(isDisabled:Bool):View {
		modifierChain.push(Disabled(isDisabled));
		return this;
	}

	public function hidden():View {
		modifierChain.push(Hidden);
		return this;
	}

	// Navigation & Presentation
	public function navigationTitle(title:String):View {
		modifierChain.push(NavigationTitle(title));
		return this;
	}

	// Accessibility
	public function accessibilityLabel(label:String):View {
		modifierChain.push(AccessibilityLabel(label));
		return this;
	}
}
