import aui.App;
import aui.View;
import aui.ui.Image;
import aui.ui.Text;
import aui.ui.VStack;

/**
	Utilise un type que le renderer dynamique ne dessine pas.

	L'`Image` est dans une **méthode auxiliaire**, pas dans `body()` : un
	`taskItem(...)` est du rendu autant que `body()`, et ne pas l'y suivre
	laisserait passer précisément ce que les vraies apps écrivent.
**/
class NonCouvert extends App {
	public function new() {
		super();
		appName = "NonCouvert";
		packageName = "com.aui.noncouvert";
	}

	public static function main() {}

	function illustration():View {
		return new Image("logo");
	}

	override public function body():View {
		return new VStack(null, null, [new Text("saisie"), illustration()]);
	}
}
