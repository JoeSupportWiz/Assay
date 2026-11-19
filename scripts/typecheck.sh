#!/bin/sh
# Typecheck all Swift under App/ against the on-device iOS SDK (no Xcode). Usage: sh scripts/typecheck.sh
set -e
cd "$(dirname "$0")/.."
FE=$(command -v swift-frontend || echo /usr/local/swift/bin/swift-frontend)
SDK=${SDK:-$HOME/.ios-sdk/iPhoneOS27.1.sdk}
TC=$(dirname "$(dirname "$(readlink -f "$FE")")")
RD=$HOME/.cache/ios-dev/swift-resource
mkdir -p "$RD/iphoneos"; [ -e "$RD/clang" ] || ln -s "$TC/lib/swift/clang" "$RD/clang"
CACHE=$HOME/.cache/ios-dev/swift-module-cache/assay-typecheck
mkdir -p "$CACHE"
FILES=$(find App -name '*.swift' | sort)
exec "$FE" -frontend -typecheck $FILES -target arm64-apple-ios17.0 -sdk "$SDK" \
  -resource-dir "$RD" -module-cache-path "$CACHE" -module-name Assay -swift-version 5 -parse-as-library \
  ${EXTRA:-}
