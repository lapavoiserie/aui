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

echo "aui — moitie Haxe du renderer dynamique"

# A JVM stand-in for the Compose-backed state bridge.
javac -d test/stubs-classes test/stubs/aui/state/StateBridge.java || exit 1

haxe -cp src -cp test -lib rui -lib nui -D jvm --jvm test/nui-check.jar -main NuiCheck || exit 1

# Haxe puts root-package classes under `haxe.root` on the JVM; the manifest
# names the real entry point, so run the jar rather than guessing the class.
java -cp "test/nui-check.jar:test/stubs-classes" haxe.root.NuiCheck
