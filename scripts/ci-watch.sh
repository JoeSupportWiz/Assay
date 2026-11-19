#!/bin/sh
# Poll an Actions run; print step states and, on failure, the build errors. Usage: sh scripts/ci-watch.sh <run_id>
RUN=$1; R=JoeSupportWiz/Assay; H="Authorization: Bearer $GITHUB_TOKEN"
curl -s -H "$H" "https://api.github.com/repos/$R/actions/runs/$RUN/jobs" | python3 -c '
import sys,json
for j in json.load(sys.stdin)["jobs"]:
    print(j["name"], j["status"], j["conclusion"])
    for s in j["steps"]:
        if s["status"]!="queued": print("  ", s["name"], "-", s["conclusion"] or s["status"])
'
JOB=$(curl -s -H "$H" "https://api.github.com/repos/$R/actions/runs/$RUN/jobs" | python3 -c 'import sys,json; j=json.load(sys.stdin)["jobs"][0]; print(j["id"] if j["conclusion"]=="failure" else "")')
if [ -n "$JOB" ]; then
  curl -sL -H "$H" "https://api.github.com/repos/$R/actions/jobs/$JOB/logs" -o /tmp/assay-job.log
  echo "--- errors ---"
  rg -n 'error:|❌|fatal' /tmp/assay-job.log | sed 's/^[0-9]*:[0-9TZ:.-]* //' | sort -u | head -60
fi
