#!/bin/sh
# Installs the reviewed, stdlib-only reader on this Minis installation. Does not mount or read a report folder.
set -eu
name=assay-reports
root="$HOME/.local/lib/assay-minis"
# Use an isolated interpreter and a folder outside any mounted data directory.
case "$root" in *' '*) echo 'Choose a Minis home path without spaces.' >&2; exit 1;; esac
src=$(cd "$(dirname "$0")" && pwd)/assay_reports.py
if timeout 15 minis-mcp-cli info "$name" >/dev/null 2>&1; then
    echo 'assay-reports already registered; not overwriting. See integration docs to manage or remove.' >&2
    exit 2
fi
umask 077
mkdir -p "$root"
if [ -e "$root/assay_reports.py" ]; then
    cmp -s "$src" "$root/assay_reports.py" || { echo 'A different reader already exists; not replacing.' >&2; exit 2; }
else
    install -m 600 "$src" "$root/assay_reports.py"
fi
timeout 30 minis-mcp-cli add --name "$name" --command /usr/bin/python3 --args "-I $root/assay_reports.py" --note 'Read only reviewed Assay diagnostic exports in the user-mounted Assay Reports folder. No device or network commands.'
