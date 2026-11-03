#!/bin/sh
# Builds talk.pdf from talk.livemd. Runs all cells, so the PDF shows their outputs.
#
#     sh pdf/build.sh
#
# Needs the tools from .tool-versions and Google Chrome. Set CHROME to use
# another Chrome or Chromium binary.
set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
chrome=${CHROME:-"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# asdf finds the tool versions from .tool-versions in the current folder.
cd "$root"

elixir --name notebook@127.0.0.1 --erl "-hidden" pdf/render.exs talk.livemd "$tmp/talk.html"

# The budget gives the fonts and the Mermaid diagrams time to load.
"$chrome" --headless --disable-gpu --no-pdf-header-footer --generate-pdf-document-outline \
  --virtual-time-budget=30000 --user-data-dir="$tmp/chrome" \
  --print-to-pdf="$root/talk.pdf" "file://$tmp/talk.html" 2>/dev/null

echo "Wrote talk.pdf"
