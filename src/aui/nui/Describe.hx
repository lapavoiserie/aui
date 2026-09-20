package aui.nui;

import aui.View;
import aui.state.State;
import nui.Node;
import nui.PropValue;

/**
	Describes an aui view tree as `nui` nodes — the outward half a detached
	surface needs (a Companion projection today, a widget snapshot in P4a).
	Mirror of cui's `Describe` and wui's `FromViews`.

	`ViewSource` lets a foreign consumer *walk* an aui tree through the pull
	contract; this produces a `Node` tree outright, which is what
	`nui.Snapshot.project` eats. The distinction matters because the pull
	contract cannot enumerate props — a walker asks by name — while a
	projection must carry everything.

	## The canon

	Types and props are the CANONICAL mui names — `Text`/`text`,
	`Button`/`label`+`onClick`, `Toggle`/`isOn`+`onToggle`,
	`TextInput`/`text`+`placeholder`+`onText`, `Slider`/`value`+`onValue` —
	never aui's spelling, so a snapshot of an aui-served tree and of a
	cui-served one look the same on the wire and one sink renders both.

	## Describing samples

	aui's dynamic path runs `LiveProps`: a node is constructed with neutral
	values and the truth lives behind its `liveBuild` thunk. Every field read
	here goes through `ViewSource.resolveValue` first — reading the neutral
	node would describe empty strings and zeros, the exact mistake
	`resolveValue`'s own doc records. Reading the cells here is also what
	subscribes the surrounding projection effect to them: liveness is the
	effect around the describe, never the tree.

	A `ConditionalView`'s condition is read live, a `ForEach` is spliced into
	its siblings (reusing `ViewSource`'s expansion — `@:access`ed rather than
	mirrored, so there is one answer to "what does this loop yield"), a
	`ViewComponent` is expanded through its body. `Text.withState` templates
	are resolved against the state registry, because a snapshot is one
	sampled picture and a template is a name with nothing to look it up in on
	the far side.

	## Identity

	aui carries no sibling keys (`ViewSource.keyOf` says why). Keys stay
	null; the receiving renderer's identity is positional, like aui's own.
**/
@:access(aui.nui.ViewSource)
class Describe {
	/** Describe a view tree, or an empty root when there is nothing. **/
	public static function describe(view:View):Node {
		if (view == null) return new Node("VStack");
		var expansion:Array<Node> = [];
		if (expanded(view, expansion)) {
			// Where one node is expected there are no siblings to become: an
			// expansion at the root is wrapped in the stack it would fill.
			var root = new Node("VStack");
			for (child in expansion) root.child(child);
			return root;
		}
		return node(view);
	}

	// One walker instance for action invocation: `invokeAction` applies a
	// declarative StateAction or fires the OnTapGesture closure — the exact
	// answer the dynamic renderer gives a tap, reused rather than restated.
	// Instance state is never touched by that path; null is an honest root.
	static final invoker = new ViewSource(null);

	/** Nodes with no rendering of their own, expanded before the wire sees
		them — the rule every backend's walk follows, on the describe side. **/
	static function expanded(view:View, into:Array<Node>):Bool {
		if (view == null) return true;
		var resolved = ViewSource.resolve(view);
		if (resolved != view) {
			// A component chain: describe what it expands to.
			if (resolved != null && !expanded(resolved, into)) into.push(node(resolved));
			return true;
		}
		if (view.viewType == "ConditionalView") {
			var cond:Null<State<Bool>> = (cast view : aui.ui.ConditionalView).conditionState;
			// Sampled live, not the branch construction froze: a describe is
			// the current picture. A condition without a cell cannot be
			// answered; the then-branch would be a guess, so nothing is.
			if (cond == null) return true;
			var c:aui.ui.ConditionalView = cast view;
			var taken = cond.get() ? c.thenView : c.elseView;
			if (taken != null && !expanded(taken, into)) into.push(node(taken));
			return true;
		}
		if (view.viewType == "ForEach") {
			// ViewSource owns the expansion knowledge (items-or-State source,
			// iterables, the builder call); one answer, not two that drift.
			var items = ViewSource.forEachItems(view);
			if (items != null) for (item in items) {
				if (item == null) continue;
				if (!expanded(item, into)) into.push(node(item));
			}
			return true;
		}
		return false;
	}

	/**
		The describer for a view's class, or its nearest declared ancestor's.

		A walk up the chain rather than a `switch` on `viewType`, which is a
		string a constructor happens to set. It answered well here -- `aui` was
		never order-dependent the way the others were -- but a name written in
		two places is still a name written in two places, and the class is the
		thing that cannot disagree with itself.
	**/
	static function declaredFor(view:View):Null<View->Node> {
		var cls = Type.getClass(view);
		while (cls != null) {
			var found = Derived.DESCRIBERS.get(Type.getClassName(cls));
			if (found != null) return found;
			cls = cast Type.getSuperClass(cls);
		}
		return null;
	}

	static function node(view:View):Node {
		// The truth lives behind the LiveProps thunk; the constructed node
		// holds neutral values. Resolve first, always.
		var v = ViewSource.resolveValue(view);
		if (v == null) return new Node("VStack");

		// Three views are not vocabulary, and each says why; everything else is
		// generated from what the controls declare -- see aui.nui.Derive.
		//
		// Asked BEFORE the declarations, which is the one place order still
		// matters here: three named exceptions rather than seventeen branches.
		var out:Node = switch (v.viewType) {
			case "Button":
				var b:aui.ui.Button = cast v;
				// The tap does what the dynamic renderer's tap does: apply the
				// declarative StateAction, else the OnTapGesture closure — the
				// mui facade's route. The ORIGINAL view is captured, not the
				// resolved copy: the modifier chain with the closure lives on
				// whichever node the tree holds.
				var button = new Node("Button")
					.prop("label", PString(b.label))
					.prop("onClick", PCallback(() -> invoker.invokeAction(view)));
				if (b.properties.exists("icon")) button.prop("icon", PString(Std.string(b.properties.get("icon"))));
				button;

			case "TabView":
				// NOT described as the canon's `Tabs`, and the reason is
				// smaller and worse than "a boundary is in the way", which is
				// what this comment said first.
				//
				// `aui.ui.TabView(tabs)` has **no selection at all**. Not one
				// kept somewhere awkward -- none: whoever draws it invents
				// one and keeps it beside the tree. `Tabs` carries
				// `selectedIndex`, so describing one would mean sending a
				// number this side does not have, and a bar showing the wrong
				// tab is worse than no bar because it looks right.
				//
				// That is exactly the defect the canon names -- "a selection
				// living inside the control could not be reached" from
				// elsewhere -- and the fix is the one `cui.ui.Tabs` just got:
				// the application owns the selection, and the tabs are views
				// rather than a typedef. It is an API change to this control
				// and to what `ComposeGenerator` emits for it, so it is real
				// work rather than a line, and it is NOT blocked.
				//
				// A received `Tabs` builds fine (`DynamicComposable.kt`).
				trace("aui.nui.Describe: TabView flattened to its first tab");
				var tabs:Null<Array<aui.ui.Tab>> = ViewSource.tabsOf(v);
				var n = new Node("VStack");
				if (tabs != null && tabs.length > 0 && tabs[0].content != null) {
					var into:Array<Node> = [];
					if (!expanded(tabs[0].content, into)) into.push(node(tabs[0].content));
					for (child in into) n.child(child);
				}
				n;

			// aui's SafeArea is Compose insets handling; the wire has no insets
			// to honor, so the honest name is the stack it wraps.
			case "SafeArea": withChildren(new Node("VStack"), v);

			case other:
				var declared = declaredFor(v);
				if (declared != null) declared(v);
				else {
					// Loud rather than invisible: the receiving side draws
					// "?Name" and the name says whose.
					var dot = other.lastIndexOf(".");
					withChildren(new Node(dot >= 0 ? other.substr(dot + 1) : other), v);
				}
		}

		describeModifiers(v, out);
		return out;
	}

	/**
		A Text's current string. `withState` templates carry names, and a name
		is nothing on the far side of a wire — each `{cell}` is sampled from
		the registry now, which also puts the read inside the projection
		effect where it subscribes.
	**/
	static function sampleText(t:aui.ui.Text):String {
		if (t.stateTemplate == null) return t.content == null ? "" : t.content;
		return ~/\{([^}]+)\}/g.map(t.stateTemplate, function(r) {
			var cell:Dynamic = State.getByName(r.matched(1));
			if (cell == null) return r.matched(0); // unknown name: left visible
			return Std.string(cell.get());
		});
	}

	/**
		Splice a view's children into its node. Called by the generated
		describers, which know a container's children go here and nothing else
		about them.
	**/
	public static function appendChildren(view:View, out:Node):Node
		return withChildren(out, view);

	static function withChildren(out:Node, view:View):Node {
		if (view.children != null) for (child in view.children) {
			if (child == null) continue;
			var into:Array<Node> = [];
			if (expanded(child, into)) {
				for (n in into) out.child(n);
			} else {
				out.child(node(child));
			}
		}
		return out;
	}

	/**
		aui's typed modifier enum as nui's name-plus-positional form — the
		visual and layout subset the wire can say. Gesture modifiers are
		deliberately absent: behavior crossed as `onClick` already, and a
		closure has no wire form outside the action table.
	**/
	static function describeModifiers(view:View, out:Node):Void {
		if (view.modifierChain == null) return;
		for (m in view.modifierChain) {
			var described:Null<nui.Modifier> = switch (m) {
				case Padding(v): {type: "padding", floats: v == null ? [] : [v]};
				case PaddingHorizontal(v): {type: "paddingHorizontal", floats: [v]};
				case PaddingVertical(v): {type: "paddingVertical", floats: [v]};
				case Font(style): {type: "font", strings: [Std.string(style)]};
				case Bold: {type: "bold"};
				case Italic: {type: "italic"};
				// The chain already holds the canon's word -- see aui.nui.Colors.
				case ForegroundColor(said): {type: nui.Modifiers.FOREGROUND_COLOR, strings: [said]};
				case Background(said): {type: nui.Modifiers.BACKGROUND_COLOR, strings: [said]};
				case Opacity(v): {type: "opacity", floats: [v]};
				case CornerRadius(r): {type: "cornerRadius", floats: [r]};
				case Border(c, w): {type: "border", strings: [Std.string(c)], floats: w == null ? [] : [w]};
				// A rectangle IS the canon's `clip`. The other shapes have no
				// canon name and keep falling through below.
				case ClipShape(Rectangle): {type: nui.Modifiers.CLIP};
				case OnTapGesture(_) | OnLongPressGesture(_): null;
				case _: null; // no wire form; dropped silently is fine for visuals
			}
			if (described != null) out.modifier(described);
		}
	}
}
