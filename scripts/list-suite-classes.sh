#!/usr/bin/env bash
# Print a space-separated, de-duplicated list of the test class names in the
# named ApexTestSuite(s). `sf project deploy start` takes `--tests <classes>`
# (space-separated, one flag) but not `--suite-names`, so a check-only deploy
# needs the list spelled out.
#
# Usage: list-suite-classes.sh XFTY_Unit XFTY_Integration ...
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
files=()
for suite in "$@"; do
  match=$(find "$root/force-app" "$root/test-support" -name "${suite}.testSuite-meta.xml")
  if [ -z "$match" ]; then
    echo "no suite file for '${suite}'" >&2
    exit 1
  fi
  files+=("$match")
done

grep -h -oE '<testClassName>[^<]+' "${files[@]}" \
  | sed 's#<testClassName>##' \
  | sort -u \
  | paste -sd' '
