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
cover() {
	local fixture="$1" expect="$2" type="${3:-}" out code work
	work=$(mktemp -d)
	out=$(cd "$work" && haxe -cp "$root/src" -cp "$root/test/coverage" -lib rui -lib nui \
		-D jvm --jvm coverage-check.jar -D aui_dynamic \
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

[ $failures -eq 0 ] || { echo ""; echo "coverage: failed"; exit 1; }
echo ""
echo "all good"
