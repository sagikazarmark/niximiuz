#!/usr/bin/env bash
# Sample script exercising readBlock extraction.

echo "preamble"

# @block:install
curl -fsSL https://example.com | sh
apt-get install -y foo
# @endblock

echo "middle"

# @block:cleanup
rm -rf /tmp/work
# @endblock

echo "tail"
