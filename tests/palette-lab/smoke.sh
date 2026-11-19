#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc App/Features/PaletteLab/PaletteLabCore.swift tests/palette-lab/PaletteLabTests.swift -o "$build/palette-tests"
"$build/palette-tests"
