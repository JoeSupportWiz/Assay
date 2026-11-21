#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
swiftc -swift-version 5 -parse-as-library App/Features/Supporter/SupporterEntitlement.swift \
    tests/supporter/EntitlementFixture.swift -o "$dir/check"
"$dir/check"
