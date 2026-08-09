package aui;

/**
	A reusable piece of view, written as a class.

	Composing with a method already works — `function card(t, v):View return new
	HStack(...)` — and needs nothing from the framework. This is for a component
	that wants **its own state**:

	```haxe
	class Counter extends ViewComponent {
		@:state var n:Int = 0;
		public var label:String;

		public function new(label:String) {
			super();
			this.label = label;
		}

		override public function body():View {
			return new HStack(null, [
				new Text(label + ": " + n.get()),
				new Button("+", n.inc())
			]);
		}
	}
	```

	`@:autoBuild` is what buys that: the same pass that turns an app's `@:state`
	fields into cells runs here too, and so does the deferral of view values.

	## What it is not

	**Not a new primitive.** A component is *expanded* — the renderer draws what
	its `body()` returns, so it can only be made of node types the renderer
	already knows. Adding a genuinely new kind of node, one that maps to a Compose
	widget nothing else produces, still means teaching the renderer about it.

	The distinction is worth keeping straight, because the two get called the same
	thing: composing existing views is unlimited, introducing a new leaf is not.

	## Where it is expanded

	`aui.nui.ViewSource` resolves a component to its `body()` when it describes
	the tree, so a consumer walking through nui's pull contract never sees the
	component itself — only what it renders. The expansion is computed once per
	node: a value that changes is handled by the deferral in `aui.macros.LiveProps`,
	not by rebuilding the component.
**/
@:autoBuild(aui.macros.StateMacro.build())
class ViewComponent extends View {
	/** The expansion, kept so walking the tree does not rebuild it per question. **/
	@:noCompletion var _expanded:Null<View> = null;

	public function new() {
		super();
		viewType = "ViewComponent";
	}

	/** What this component renders. Override it. **/
	override public function body():View {
		return new View();
	}

	/** `body()`, computed once. **/
	@:noCompletion public function expand():View {
		if (_expanded == null) _expanded = body();
		return _expanded;
	}
}
