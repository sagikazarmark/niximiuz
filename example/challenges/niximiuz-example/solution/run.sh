#!/usr/bin/env bash
# niximiuz example, challenge solver.
#
# Argument: a running playground ID. Writes the marker the verifier
# (verify_challenge_answer) greps for.

set -euo pipefail

playId="${1:?usage: $0 <play-id>}"

labctl ssh --machine ubuntu --user laborant "$playId" -- \
  'echo Niximiuz > /tmp/niximiuz-challenge-answer'
