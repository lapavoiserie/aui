package aui.glance

/**
 * The seam between "the application asked for a new sample" and the widget
 * that takes it.
 *
 * `mui.surface.Resample.request(Glance)` reaches Haxe's `aui.glance.GlanceHost`
 * extern, which is this object — resolved by the ordinary JVM class loader,
 * the same way `aui.state.StateBridge` is, since the Haxe jar and the Kotlin
 * classes share one APK classpath.
 *
 * It holds no widget logic of its own on purpose. The code that knows how to
 * push a picture is generated into the *application's* package (it names the
 * app class and the widget class, both of which vary), so it registers itself
 * here as a `Pusher` when the process boots. A fixed package on this side is
 * what lets Haxe name it at all.
 *
 * With nothing registered the request is dropped, deliberately without a
 * word: a process that has neither shown the app nor served the widget has
 * nothing to refresh, and a trace on every such call would be noise, not
 * information.
 */
object GlanceHost {
    fun interface Pusher {
        fun push()
    }

    @JvmStatic
    var pusher: Pusher? = null

    @JvmStatic
    fun requestUpdate() {
        pusher?.push()
    }
}
