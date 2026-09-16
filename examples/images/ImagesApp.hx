import mui.App;
import mui.View;
import mui.ui.HStack;
import mui.ui.Icon;
import mui.ui.IconName;
import mui.ui.Image;
import mui.ui.ScrollView;
import mui.ui.Text;
import mui.ui.VStack;

/**
	Every icon of `nui.Icons`, and a picture from each source aui draws itself,
	with the failures that must show their `alt`, and buttons with an icon.

	Pictures: `data:` contained and covered, `file:` (written at start-up from
	the same bytes), and three that cannot be drawn — an asset this build does
	not ship, an `http:` source, and a `data:` source that is not a PNG.
**/
class ImagesApp extends App {
	final filePath:String;

	@:state var taps:Int = 0;

	public function new() {
		super();
		appTitle = "aui images";
		// The application's own cache directory: the only place it may write.
		filePath = haxe.io.Path.join([java.lang.System.getProperty("java.io.tmpdir"), "aui-images-test.png"]);
		sys.io.File.saveBytes(filePath, haxe.crypto.Base64.decode(TestPicture.BASE64));
	}

	override function body():View {
		var data = "data:image/png;base64," + TestPicture.BASE64;
		var rows:Array<View> = [
			new Text("Buttons: " + taps),
			new HStack([
				button("TAKE", "swap"),
				button("", "mic-off"),
				button("Plain", null),
			], 12),
			new Text("Icons"),
		];
		var names = nui.Icons.NAMES;
		var perRow = 6;
		var i = 0;
		while (i < names.length) {
			var cells:Array<View> = [];
			for (name in names.slice(i, i + perRow))
				cells.push(new VStack([new Icon(IconName.fromString(name)), new Text(name)], 2));
			rows.push(new HStack(cells, 14));
			i += perRow;
		}
		rows.push(new Text("Pictures"));
		rows.push(new HStack([
			new Image(data, "contained", {width: 96}),
			new Image(data, "covered", {width: 64, height: 64, fit: Cover}),
			new Image("file://" + filePath, "from a file", {width: 96}),
		], 12));
		rows.push(new HStack([
			new Image("asset:not-shipped.png", "missing asset", {width: 96, height: 48}),
			new Image("http://example.org/a.png", "http is refused", {width: 96, height: 48}),
			new Image("data:image/png;base64,SGVsbG8=", "not a PNG", {width: 96, height: 48}),
		], 12));
		return new ScrollView([new VStack(rows, 8)]);
	}

	function button(label:String, icon:Null<String>):View {
		var b = new aui.ui.Button(label, null, icon);
		b.onTapGesture(() -> taps = taps + 1);
		return b;
	}

	static function main() {}
}
