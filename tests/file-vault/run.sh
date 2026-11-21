#!/bin/sh
# Runs the production store, not a reimplementation. Requires macOS + Xcode CLT.
set -eu
cd "$(dirname "$0")/../.."
bin=$(mktemp -d)
trap 'rm -rf "$bin"' EXIT
xcrun --sdk macosx swiftc -swift-version 5 -parse-as-library \
    App/Features/FileVault/VaultIO.swift App/Features/FileVault/VaultStore.swift \
    tests/file-vault/VaultFixture.swift -o "$bin/fixture"
"$bin/fixture"
