#!/bin/sh
# release verifier: the build report must carry the verification marker
grep -q "STATUS: VERIFIED" build/report.txt || { echo "verify FAILED"; exit 1; }
echo "verify OK"
