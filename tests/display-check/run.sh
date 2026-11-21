#!/bin/sh
# Portable Foundation fixtures; the app view is also syntax checked without an iOS SDK.
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
src=App/Features/DisplayCheck
# ContinuousClock is available on macOS 13+; do not inherit swiftc's older default target.
if [ "$(uname -s)" = Darwin ]; then export MACOSX_DEPLOYMENT_TARGET=13.0; fi
swiftc -parse "$src"/*.swift
swiftc -swift-version 5 -parse-as-library "$src/DisplayEvidence.swift" tests/display-check/Smoke.swift -o "$build/smoke"
"$build/smoke" "$@"
swiftc -swift-version 5 -parse-as-library "$src/DisplayEvidence.swift" "$src/DisplayClockReport.swift" tests/display-check/ClockReportFixture.swift -o "$build/report"
"$build/report"
