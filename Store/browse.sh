#!/bin/sh
# Run one ~/ios-7 browser script under the shared browser.lock. Usage: Store/browse.sh <script.js> (env passes through)
L=/c/Users/Matthew/ios-7/browser.lock
while [ -e "$L" ]; do sleep 5; done
echo baseline-ledger > "$L"
cd /c/Users/Matthew/ios-7 && node asc-do.mjs "$1"; rc=$?
rm -f "$L"
exit $rc
