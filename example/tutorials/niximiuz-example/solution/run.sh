#!/usr/bin/env bash
# niximiuz example, tutorial solver.
#
# Argument: a running playground ID. Creates the marker file that
# verify_marker_file checks for.

set -euo pipefail

playId="${1:?usage: $0 <play-id>}"

labctl ssh --machine ubuntu --user laborant "$playId" -- touch /tmp/niximiuz-tutorial-done
