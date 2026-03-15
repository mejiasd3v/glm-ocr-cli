#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

if [[ $# -lt 1 ]]; then
  echo "Usage: ocr <pdf-or-image-or-dir> [glmocr flags...]" >&2
  echo "   or: bash $OCR_SKILL_DIR/scripts/parse.sh <pdf-or-image-or-dir> [glmocr flags...]" >&2
  exit 1
fi

ocr_ensure_setup

SDK_BIN="$OCR_SDK_VENV/bin/glmocr"
INPUT="$1"
shift

STARTED_SERVER=0
if ocr_server_running; then
  echo "[ocr] reusing running server at ${OCR_HOST}:${OCR_PORT}" >&2
else
  ocr_start_server_bg
  STARTED_SERVER=1
fi

if [[ ! -e "$INPUT" ]]; then
  echo "Input not found: $INPUT" >&2
  exit 1
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
