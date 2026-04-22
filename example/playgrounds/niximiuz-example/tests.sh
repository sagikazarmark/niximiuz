#!/usr/bin/env bash
# niximiuz example, hello playground smoke test.
#
# Runs over SSH into the started session. Verifies the machine booted,
# the shell works, and the default user matches what the manifest
# declares. Deliberately independent of image-baked state so the test
# stays meaningful even if the Dockerfile changes.

set -euo pipefail

test "$(whoami)" = "laborant"
test "$(uname -s)" = "Linux"
test -d /home/laborant

echo "hello playground: smoke test passed"
