#!/bin/sh
# No secrets, GitHub calls, purchases, downloads or devices required.
set -eu
cd "$(dirname "$0")/../.."
o=$(mktemp -d); trap 'rm -rf "$o"' EXIT
python3 tests/build-library/make-fixtures.py "$o"
swiftc -parse-as-library App/Features/BuildLibrary/SignetBuildRef.swift App/Features/BuildLibrary/SignetBuildClient.swift App/Features/Signet/SignetZip.swift tests/build-library/Fixture.swift -o "$o/check"
"$o/check" "$o"
