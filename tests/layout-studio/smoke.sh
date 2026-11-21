#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc App/Features/LayoutStudio/LayoutRecipe.swift App/Features/LayoutStudio/LayoutArchive.swift \
    tests/layout-studio/LayoutStudioTests.swift -o "$build/layout-tests"
"$build/layout-tests"
