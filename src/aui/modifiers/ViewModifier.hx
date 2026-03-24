package aui.modifiers;

import aui.View;
import aui.state.State;
import aui.state.StateAction;

enum ViewModifier {
	// Layout
	Padding(?value:Float);
	PaddingHorizontal(value:Float);
	PaddingVertical(value:Float);
	Frame(?width:Float, ?height:Float, ?maxWidth:Float, ?maxHeight:Float, ?alignment:Alignment);
	FillMaxWidth;
	FillMaxHeight;
	FillMaxSize;
	Offset(x:Float, y:Float);
	AspectRatio(?ratio:Float, ?contentMode:ContentMode);

	// Typography
	Font(style:FontStyle);
	Bold;
	Italic;
	LineLimit(lines:Int);
	MultilineTextAlignment(alignment:TextAlignment);

	// Colors & Effects
	ForegroundColor(color:ColorValue);
	Background(color:ColorValue);
	Opacity(value:Float);
	CornerRadius(radius:Float);
	ClipShape(shape:ShapeType);
	Shadow(?color:ColorValue, ?radius:Float, ?x:Float, ?y:Float);
	Blur(radius:Float);
	ScaleEffect(scale:Float);
	RotationEffect(degrees:Float);
	Brightness(amount:Float);
	Contrast(amount:Float);
	Saturation(amount:Float);
	Grayscale(amount:Float);

	// Border & Overlay
	Border(color:ColorValue, ?width:Float);
	Overlay(content:View);

	// Interaction
	OnTapGesture(action:() -> Void);
	OnLongPressGesture(action:() -> Void);
	OnAppear(action:() -> Void);
	OnDisappear(action:() -> Void);
	Disabled(isDisabled:Bool);
	Hidden;

	// Presentation
	Sheet(isPresented:State<Bool>, content:View);
	Alert(title:String, isPresented:State<Bool>, ?message:String);
	NavigationTitle(title:String);

	// Animation
	Animation(curve:AnimationCurve);

	// Accessibility
	AccessibilityLabel(label:String);
	AccessibilityHint(hint:String);
}

enum ColorValue {
	Primary;
	Secondary;
	Accent;
	Red;
	Orange;
	Yellow;
	Green;
	Blue;
	Purple;
	Pink;
	White;
	Black;
	Gray;
	Transparent;
	Custom(hex:String);
}

enum FontStyle {
	DisplayLarge;
	DisplayMedium;
	DisplaySmall;
	HeadlineLarge;
	HeadlineMedium;
	HeadlineSmall;
	TitleLarge;
	TitleMedium;
	TitleSmall;
	BodyLarge;
	BodyMedium;
	BodySmall;
	LabelLarge;
	LabelMedium;
	LabelSmall;
	CustomFont(name:String, size:Float);
}

enum Alignment {
	Center;
	TopStart;
	TopCenter;
	TopEnd;
	CenterStart;
	CenterEnd;
	BottomStart;
	BottomCenter;
	BottomEnd;
}

enum TextAlignment {
	Start;
	Center;
	End;
}

enum ContentMode {
	Fit;
	Fill;
}

enum ShapeType {
	Rectangle;
	RoundedRectangle(radius:Float);
	Circle;
	Capsule;
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
