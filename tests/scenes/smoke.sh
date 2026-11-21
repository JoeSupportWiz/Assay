#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc App/Features/Scenes/SceneLibraryState.swift App/Features/Scenes/SceneLibraryStore.swift tests/scenes/SceneSmoke.swift -o "$build/scenes"
"$build/scenes"
