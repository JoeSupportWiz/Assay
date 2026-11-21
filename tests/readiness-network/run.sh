#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# Foundation's strict URL parser needs macOS 14+ (app deployment: iOS 17+).
if [ "$(uname -s)" = Darwin ]; then export MACOSX_DEPLOYMENT_TARGET=14.0; fi
swiftc -swift-version 5 -parse App/Features/Network/NetworkTLS.swift \
    App/Core/AIDiagnosis.swift App/Features/Alchemy/AIChatModel.swift
swiftc -swift-version 5 App/Core/LocalNetworkHost.swift App/Core/AIPrivacy.swift \
    App/Core/AIProvider.swift App/Core/AIClient.swift App/Features/Network/NetworkModels.swift \
    tests/readiness-network/Fixture.swift -o "$tmp/check"
"$tmp/check"
