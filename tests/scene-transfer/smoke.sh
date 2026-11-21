#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
swiftc App/Features/Scenes/SceneLibraryState.swift App/Features/SceneTransfer/ScenePacket*.swift \
    tests/scene-transfer/TransferSmoke.swift -o "$build/transfer"
"$build/transfer"
