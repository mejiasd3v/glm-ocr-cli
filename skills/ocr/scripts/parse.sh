#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

usage() {
  cat <<EOF >&2
Usage:
  ocr <pdf-or-image-or-dir> [glmocr flags...]
  ocr parse <pdf-or-image-or-dir> [glmocr flags...]

Examples:
  ocr ./invoice.pdf --stdout
  ocr ./receipt.jpg --stdout --no-save
  ocr ./scans --output ./ocr-results
  GLMOCR_ENABLE_LAYOUT=1 ocr ./invoice.pdf --stdout
EOF
}

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

case "${1:-}" in
  -h|--help|help)
    usage
    exit 0
    ;;
  -v|--version|version)
    if command -v node >/dev/null 2>&1; then
      node -p "require('$OCR_SKILL_DIR/../../package.json').version"
    else
      echo "unknown"
    fi
    exit 0
    ;;
esac

INPUT="$1"
shift

if [[ ! -e "$INPUT" ]]; then
  echo "[ocr] input not found: $INPUT" >&2
  exit 1
fi

ocr_ensure_setup

SDK_BIN="$OCR_SDK_VENV/bin/glmocr"
STARTED_SERVER=0
if ocr_server_running; then
  echo "[ocr] reusing running server at ${OCR_HOST}:${OCR_PORT}" >&2
else
  ocr_start_server_bg
  STARTED_SERVER=1
fi

HAS_CONFIG=0
for ARG in "$@"; do
  if [[ "$ARG" == "--config" || "$ARG" == "-c" ]]; then
    HAS_CONFIG=1
    break
  fi
done

TMP_CONFIG=""
cleanup() {
  if [[ -n "$TMP_CONFIG" && -f "$TMP_CONFIG" ]]; then
    rm -f "$TMP_CONFIG"
  fi
  if [[ "$STARTED_SERVER" -eq 1 ]]; then
    ocr_stop_server >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ "$HAS_CONFIG" -eq 0 ]]; then
  TMP_CONFIG="$(mktemp)"
  ocr_make_temp_config "$TMP_CONFIG"
fi

CMD=("$SDK_BIN" parse "$INPUT")
if [[ "$HAS_CONFIG" -eq 0 ]]; then
  CMD+=(--config "$TMP_CONFIG")
fi
if [[ $# -gt 0 ]]; then
  CMD+=("$@")
fi

echo "[ocr] running: ${CMD[*]}" >&2
"${CMD[@]}"
