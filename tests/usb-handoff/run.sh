#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
src=App/Features/USBHandoff
swiftc -swift-version 5 -parse "$src"/*.swift
swiftc -swift-version 5 "$src/USBProtocol.swift" "$src/USBJobStore.swift" tests/usb-handoff/Smoke.swift -o "$tmp/check"
"$tmp/check" "$tmp"
