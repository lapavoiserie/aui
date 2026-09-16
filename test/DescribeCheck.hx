import mui.App;
import mui.View;
import mui.ui.Text;
import mui.ui.VStack;
import mui.ui.Button;
import mui.ui.Toggle;
import mui.ui.ToggleBinding;
import mui.ui.ForEach;
import nui.PropValue;
import nui.PropValue.PropValueTools;

/**
	The aui end of the Companion pipe: a real mui-facade tree is DESCRIBED to
	canonical nodes (through the LiveProps thunks — the constructed nodes hold
	neutral values, so a describe that skipped `resolveValue` would assert
	empty strings), PROJECTED to a snapshot, carried as JSON, INFLATED, and
	invoked — the button's closure and the toggle's cell must answer across
	the whole loop.

	Runs on the JVM like NuiCheck (aui's State needs the StateBridge stub;
	the interpreter has no Compose to stand in for).

	    ./test/describe.sh
**/
class DescribeCheck extends App {
	static var fails = 0;

	static function check(label:String, ok:Bool) {
		if (!ok) fails++;
		Sys.println((ok ? "  ok   " : "  FAIL ") + label);
	}

	@:state var lit:Bool = false;
	@:state var todos:Array<String> = [];

	public function new() {
		super();
		todos = ["a", "b"];
	}

	override function body():View {
		return new VStack([
			new Text("hello"),
			new Button("Go", () -> taps.push("go")),
			new Toggle("Lamp", (lit_ : ToggleBinding)),
			ForEach.build(todos_, (s:String) -> new Text(s)),
		], 8);
	}

	static var taps:Array<String> = [];

	static function main() {
		Sys.println("aui — describe, and the Companion pipe");

		var app = new DescribeCheck();
		var described = mui.surface.Describe.describe(app.body());
		check("the hook answers", described != null);

		// --- The canon, read through the LiveProps thunks ---
		check("a stack describes with its spacing", described.type == "VStack"
			&& PropValueTools.asFloat(described.props.get("spacing")) == 8);
		check("Text carries text", described.children[0].type == "Text"
			&& PropValueTools.asString(described.children[0].props.get("text")) == "hello");
		var btn = described.children[1];
		check("Button carries label and onClick", btn.type == "Button"
			&& PropValueTools.asString(btn.props.get("label")) == "Go"
			&& btn.props.get("onClick") != null);
		var tog = described.children[2];
		check("Toggle follows the change-key canon (isOn/onToggle)", tog.type == "Toggle"
			&& PropValueTools.asBool(tog.props.get("isOn")) == false
			&& tog.props.get("onToggle") != null);

		// --- ForEach splices into siblings ---
		check("a ForEach splices its rows as siblings", described.children.length == 5
			&& PropValueTools.asString(described.children[3].props.get("text")) == "a"
			&& PropValueTools.asString(described.children[4].props.get("text")) == "b");

		// A described two-way control writes through to the cell.
		switch (PropValueTools.resolve(tog.props.get("onToggle"))) {
			case PCallbackBool(fn): fn(true);
			case _:
		}
		check("a described binding writes back to the state", app.lit == true);

		// --- The pipe: project -> wire -> inflate -> invoke ---
		var table = new nui.Snapshot.ActionTable();
		var snap = nui.Snapshot.project(described, table);
		var far = nui.Snapshot.fromJson(nui.Snapshot.toJson(snap));
		check("the snapshot carries the action ids", far.children[1].actions.get("onClick") != null);

		var inflated = nui.Snapshot.inflate(far, (id, arg) -> table.invoke(id, arg));
		switch (PropValueTools.resolve(inflated.children[1].props.get("onClick"))) {
			case PCallbackString(fn): fn("");
			case _:
		}
		check("a remote-shaped tap runs the original closure", taps.length == 1 && taps[0] == "go");

		// The toggle's typed shape crosses too: "true" parses against the
		// recorded PCallbackBool and lands in the cell.
		app.lit = false;
		switch (PropValueTools.resolve(inflated.children[2].props.get("onToggle"))) {
			case PCallbackString(fn): fn("true");
			case _:
		}
		check("a remote toggle write reaches the @:state cell", app.lit == true);

		// --- How a text is set, canonical on the wire ---
		var set = aui.nui.Describe.describe(new aui.ui.VStack(null, null, [
			new aui.mui.Text("Sources", Title),
			new aui.mui.Text("00:12:34", Body, {family: mui.ui.FontFamily.fromString("Georgia"), weight: 600, numbers: Tabular}),
			new aui.mui.Text("plain")
		]));
		check("a heading crosses as a heading, which it did not before the canon",
			PropValueTools.asString(set.children[0].props.get("scale")) == "title");
		check("a family, a weight and tabular digits cross as props",
			PropValueTools.asString(set.children[1].props.get("family")) == "Georgia"
			&& PropValueTools.asInt(set.children[1].props.get("weight")) == 600
			&& PropValueTools.asString(set.children[1].props.get("numbers")) == "tabular");
		check("and a text that said nothing carries nothing", !set.children[2].props.exists("family")
			&& !set.children[2].props.exists("weight") && !set.children[2].props.exists("italic"));

		// --- Pictures and icons, canonical on the wire ---
		var pictures = aui.nui.Describe.describe(new aui.ui.VStack(null, null, [
			new aui.mui.Image("asset:logo.png", "Farceur", {width: 120, fit: Cover}),
			new aui.mui.Icon(MicOff, "Muted"),
			new aui.mui.Icon(Play)
		]));
		var img = pictures.children[0];
		check("an Image is src, alt, width and fit", img.type == "Image"
			&& PropValueTools.asString(img.props.get("src")) == "asset:logo.png"
			&& PropValueTools.asString(img.props.get("alt")) == "Farceur"
			&& Type.enumEq(img.props.get("width"), PFloat(120))
			&& PropValueTools.asString(img.props.get("fit")) == "cover"
			&& !img.props.exists("height"));
		var mic = pictures.children[1];
		check("an Icon is its vocabulary name and label", mic.type == "Icon"
			&& PropValueTools.asString(mic.props.get("name")) == "mic-off"
			&& PropValueTools.asString(mic.props.get("label")) == "Muted");
		check("an unlabelled Icon sends no label", !pictures.children[2].props.exists("label"));
		var take = aui.nui.Describe.describe(new aui.ui.Button("TAKE", null, "swap"));
		check("a Button sends its icon's name", PropValueTools.asString(take.props.get("icon")) == "swap");
		check("and one without an icon sends none", !aui.nui.Describe.describe(new aui.ui.Button("Go")).props.exists("icon"));

		Sys.println(fails == 0 ? "\nall good" : '\n$fails failed');
		Sys.exit(fails == 0 ? 0 : 1);
	}
}
