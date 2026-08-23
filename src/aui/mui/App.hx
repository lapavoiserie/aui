package aui.mui;


/**
	`aui`'s conformance for `mui.App`.

	`mui` resolves this by name through `mui.Contract` and `mui.macros.Bind`,
	which is why nothing in `mui` mentions `aui`. Moved here, unchanged, from the
	`#if (mui_backend == "aui")` branch it used to live in.
**/
// The roles this backend can honour, stated where a macro can read them.
//
// `mui.macros.Surfaces` refuses a declaration whose role is missing from this
// list, naming this backend — degradation the application accepts on purpose
// (`@:surface(Role, optional)`) rather than degradation it never hears about.
// Widen this the day a host lands, never to quiet a build.
//
// Companion is a statement of capability, not of appetite: it says this
// backend installs a describer and *could* serve one. The networked corner
// stays off until the build asks for it with -D mui_cafos.
//
// Glance is the App Widget: the generator emits one when the application
// declares the surface, and `aui.mui.GlanceBridge` samples it — the
// snapshot-detached corner, since the launcher draws it from RemoteViews
// when the system decides, not when our state changes. Companion rides the
// describer installed below, and is served by cafos rather than by us.
@:hostedRoles(Glance, Companion)
@:autoBuild(mui.macros.Surfaces.build())
class App extends aui.App {
    public function new() {
        super();
        // The durable store, before anything durable exists. This runs inside
        // `super()` from the application's point of view, so its
        // `@:state(durable)` cells are constructed after the store is there and
        // are born from it rather than corrected afterwards.
        //
        // A macro: it expands to nothing where this platform has no store
        // implementation, so a build that asked for no durable cell does not
        // fail for a capability it never used. An application that *does* ask is
        // refused at the field, by name.
        mui.state.Durable.install();
        // The View->Node describer, for the detached corner (Companion
        // projection and the widget snapshot alike): each backend signs the
        // shared register at construction, the extraRootsOf layering.
        mui.surface.Describe.impl = v -> aui.nui.Describe.describe(v);
    }

    public var appTitle(get, set):String;
    function get_appTitle():String return appName;
    function set_appTitle(v:String):String { appName = v; return v; }

    /**
        Every surface this application declares: Primary — `body()`, always —
        plus whatever `@:surface` methods collected into `declaredSurfaces()`.
        Override to declare past the sugar: `super.surfaces().concat([…])`.
    **/
    public function surfaces():Array<mui.surface.SurfaceDecl> {
        return [mui.surface.SurfaceDecl.Tree(mui.surface.SurfaceRole.Primary, "body", () -> body())]
            .concat(declaredSurfaces());
    }

    /** What `@:surface` declared. `mui.macros.Surfaces` overrides this on the
        application; the default is the empty answer. **/
    public function declaredSurfaces():Array<mui.surface.SurfaceDecl> return [];
}
