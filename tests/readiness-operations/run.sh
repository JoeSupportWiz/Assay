#!/bin/sh
# Production storage/runner, fixture engine only; no device, app data or network access.
set -eu
cd "$(dirname "$0")/../.."
build=$(mktemp -d)
trap 'rm -rf "$build"' EXIT
if [ "$(uname -s)" = Darwin ]; then export MACOSX_DEPLOYMENT_TARGET=14.0; fi
swiftc -parse App/Features/Fix/FixViews.swift App/Features/Lab/HistoryViews.swift
swiftc -swift-version 5 -parse-as-library App/Core/Operations.swift App/Core/Models.swift \
    App/Core/Knowledge.swift App/Engine/DeviceEngine.swift tests/readiness-operations/Fixture.swift -o "$build/fixture"
"$build/fixture" "$build/data"
