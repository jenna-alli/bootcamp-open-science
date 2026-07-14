#!/usr/bin/env bash

# Render the Reveal.js deck, then print its PDF view with a local Chromium-based browser.
# Set CHROME_BIN to override browser detection, if needed.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [[ -n "${CHROME_BIN:-}" ]]; then
  chrome="$CHROME_BIN"
elif [[ -x "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ]]; then
  chrome="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
elif command -v google-chrome >/dev/null 2>&1; then
  chrome="$(command -v google-chrome)"
elif command -v google-chrome-stable >/dev/null 2>&1; then
  chrome="$(command -v google-chrome-stable)"
elif command -v chromium >/dev/null 2>&1; then
  chrome="$(command -v chromium)"
elif command -v chromium-browser >/dev/null 2>&1; then
  chrome="$(command -v chromium-browser)"
else
  echo "Error: Google Chrome or Chromium was not found. Set CHROME_BIN to its executable path." >&2
  exit 1
fi

quarto render docs/slides.qmd

chrome_profile="$(mktemp -d "${TMPDIR:-/tmp}/bootcamp-slides-chrome.XXXXXX")"
chrome_log="$(mktemp "${TMPDIR:-/tmp}/bootcamp-slides-chrome.log.XXXXXX")"
pdf_marker="$(mktemp "${TMPDIR:-/tmp}/bootcamp-slides-pdf.XXXXXX")"
cleanup() {
  rm -rf "$chrome_profile"
  rm -f "$chrome_log"
  rm -f "$pdf_marker"
}
trap cleanup EXIT

"$chrome" \
  --headless \
  --user-data-dir="$chrome_profile" \
  --no-first-run \
  --no-default-browser-check \
  --disable-gpu \
  --disable-background-networking \
  --allow-file-access-from-files \
  --virtual-time-budget=10000 \
  --no-pdf-header-footer \
  --print-to-pdf=docs/slides.pdf \
  "file://$repo_root/docs/slides.html?print-pdf" \
  2>"$chrome_log" &
chrome_pid=$!

# Chrome can keep its process alive after the PDF is safely written on macOS.
# Exit as soon as this invocation has produced a newer PDF, up to one minute.
for _ in {1..120}; do
  if [[ -s docs/slides.pdf && docs/slides.pdf -nt "$pdf_marker" ]]; then
    kill "$chrome_pid" 2>/dev/null || true
    wait "$chrome_pid" 2>/dev/null || true
    echo "Created $repo_root/docs/slides.pdf"
    exit 0
  fi
  if ! kill -0 "$chrome_pid" 2>/dev/null; then
    wait "$chrome_pid" || true
    cat "$chrome_log" >&2
    exit 1
  fi
  sleep 0.5
done

kill "$chrome_pid" 2>/dev/null || true
wait "$chrome_pid" 2>/dev/null || true
echo "Error: Chrome did not create the PDF within 60 seconds." >&2
cat "$chrome_log" >&2
exit 1
