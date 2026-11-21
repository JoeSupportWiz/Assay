#!/bin/sh
set -eu
cd -P -- "$(dirname "$0")"
# Finder-launched Terminal may omit Homebrew's binary directories.
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export PATH
exec python3 ./assay_handoff.py
