#!/bin/sh
out=$(sh check.sh)
case "$out" in
  "verify OK") echo "test PASS" ;;
  *) echo "test FAIL"; exit 1 ;;
esac
