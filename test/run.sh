#!/usr/bin/env bash
#
# Checks the Haxe half of aui's dynamic renderer.
#
# Everything it covers is reached from Kotlin by name, so no Haxe compiler ever
# sees the way it is used -- and the failure mode is silence, not a crash. See
# NuiCheck.hx.
#
#   ./test/run.sh

set -u
cd "$(dirname "$0")/.."

echo "aui — Haxe half of the dynamic renderer"

# A JVM stand-in for the Compose-backed state bridge.
javac -d test/stubs-classes test/stubs/aui/state/StateBridge.java || exit 1

# No define: the dynamic renderer is the default, so this is the build everyone
# ships. LiveProps runs, and the deferral it performs is one of the things under
# test.
haxe -cp src -cp test -lib rui -lib nui -D jvm --jvm test/nui-check.jar -main NuiCheck || exit 1

# Haxe puts root-package classes under `haxe.root` on the JVM; the manifest
# names the real entry point, so run the jar rather than guessing the class.
java -cp "test/nui-check.jar:test/stubs-classes" haxe.root.NuiCheck || exit 1

echo ""
echo "aui — dynamic renderer coverage"

# A view the dynamic renderer cannot draw must be refused at COMPILE time, not
# drawn as `?Type` at runtime. The placeholder is the right answer only for a
# tree that arrives as data, which nothing can check ahead of time -- the same
# boundary wui draws with Foreign.node.
#
# Judged on the exit code, and the refusal must name the type: any compile
# error would satisfy the code alone.
# Run from a scratch directory: ComposeGenerator emits a whole Android project
# into ./android relative to the working directory, so running the fixtures from
# the repository root buries it under a generated app -- which is what happened
# the first time.
#
# `$4` carries extra defines: empty for the default path, `-D aui_static` for
# the decommissioned one.
cover() {
	local fixture="$1" expect="$2" type="${3:-}" defines="${4:-}" out code work
	work=$(mktemp -d)
	out=$(cd "$work" && haxe -cp "$root/src" -cp "$root/test/coverage" -lib rui -lib nui \
		-D jvm --jvm coverage-check.jar $defines \
		--macro 'aui.macros.ComposeGenerator.register()' -main "$fixture" 2>&1)
	code=$?
	rm -rf "$work"

	if [ "$expect" = "pass" ]; then
		[ $code -eq 0 ] && echo "  ok   $fixture compile" || { echo "  FAIL $fixture should have compiled"; echo "$out" | sed 's/^/         /'; return 1; }
	elif [ $code -eq 0 ]; then
		echo "  FAIL $fixture should have been refused"; return 1
	elif ! echo "$out" | grep -q "\"$type\""; then
		echo "  FAIL $fixture refused without naming \"$type\""; echo "$out" | sed 's/^/         /'; return 1
	else
		echo "  ok   $fixture refused, naming \"$type\""
	fi
}

root=$(pwd)
failures=0
cover Couvert    pass              || failures=1
cover NonCouvert reject Image      || failures=1

# A view type the application declared itself: judged like any other, since the
# check watching only `aui.ui` left users' own nodes to fail silently.
cover CustomPrimitive reject Badge || failures=1

# A ViewComponent is expanded, never drawn: demanding a branch for it would be
# asking the renderer for dead code.
cover Composed   pass              || failures=1

# A ForEach is expanded too -- into siblings, by the source. It is not a node
# the renderer draws, and demanding a branch for it refused an example we ship.
cover Looped     pass              || failures=1

echo ""
echo "aui — the decommissioned static path"

# Set aside is not removed. The static transpiler is unmaintained and no longer
# the default, but a build that still asks for it must get it -- and must be
# told what it is asking for. Without a check here, the path would rot silently
# and we would find out from whoever was still on it.

# Same fixture as above, through the other renderer.
cover Couvert pass "" "-D aui_static" || failures=1

# What it costs: a component is still refused, since the static path would have
# to emit a composable carrying the component's own state.
cover Composed reject aui.ViewComponent "-D aui_static" || failures=1

# Asking for it must say it is decommissioned, at the top of the build.
work=$(mktemp -d)
out=$(cd "$work" && haxe -cp "$root/src" -cp "$root/test/coverage" -lib rui -lib nui \
	-D jvm --jvm coverage-check.jar -D aui_static \
	--macro 'aui.macros.ComposeGenerator.register()' -main Couvert 2>&1)
rm -rf "$work"
if echo "$out" | grep -q "decommissioned"; then
	echo "  ok   -D aui_static warns that the path is decommissioned"
else
	echo "  FAIL -D aui_static built without saying the path is decommissioned"
	echo "$out" | sed 's/^/         /'
	failures=1
fi

# Both defines is a leftover, not a preference: guessing either way builds
# something nobody asked for.
work=$(mktemp -d)
out=$(cd "$work" && haxe -cp "$root/src" -cp "$root/test/coverage" -lib rui -lib nui \
	-D jvm --jvm coverage-check.jar -D aui_static -D aui_dynamic \
	--macro 'aui.macros.ComposeGenerator.register()' -main Couvert 2>&1)
code=$?
rm -rf "$work"
if [ $code -ne 0 ] && echo "$out" | grep -q "contradict"; then
	echo "  ok   -D aui_static with -D aui_dynamic is refused"
else
	echo "  FAIL contradictory defines should have been refused"
	echo "$out" | sed 's/^/         /'
	failures=1
fi

[ $failures -eq 0 ] || { echo ""; echo "coverage: failed"; exit 1; }
echo ""
echo "all good"
