package aui.state;

/**
 * A stand-in for the Compose-backed StateBridge, for tests that run on a plain
 * JVM with no Android.
 *
 * The real one wraps `mutableStateOf` so a read inside a @Composable is tracked.
 * None of that is what these tests are about: they check the Haxe half -- that
 * a StateAction reaches the right cell, that the field names ViewSource reads
 * actually exist. A one-element holder answers those questions identically.
 */
public final class StateBridge {
    private static final class Cell {
        Object value;
        Cell(Object v) { value = v; }
    }

    public static Object create(Object initialValue) { return new Cell(initialValue); }

    public static Object read(Object state) { return ((Cell) state).value; }

    public static void write(Object state, Object value) { ((Cell) state).value = value; }
}
