#!/bin/bash
# tablet-verify-interactive.sh — run the read-only health check, then offer
# --fix ONLY if the check found a problem. Never auto-repairs; never prompts
# when everything is green.
#
# Exit codes:
#   0 — healthy (or repaired successfully)
#   1 — problems found and not repaired / declined / repair failed
set -u

CHECK="$HOME/.config/hypr/scripts/tablet-verify.sh"

"$CHECK"
status=$?

if [[ $status -eq 0 ]]; then
  echo
  echo "Tablet stack is healthy. Nothing to fix."
  exit 0
fi

echo
echo "The check found problems above."
printf 'Press R to repair (mechanical fixes only), or any other key to exit: '
read -r -n 1 key
echo

if [[ "$key" != "R" && "$key" != "r" ]]; then
  echo "No changes made."
  exit 1
fi

echo "Running repair..."
"$CHECK" --fix >/dev/null 2>&1

echo
echo "Re-running check after repair..."
"$CHECK"
final_status=$?

if [[ $final_status -eq 0 ]]; then
  echo "Tablet stack is healthy after repair."
  exit 0
else
  echo "Repair did not fully resolve everything. See FAIL lines above."
  exit 1
fi
