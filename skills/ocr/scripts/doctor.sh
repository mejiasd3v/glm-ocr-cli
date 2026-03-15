#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

SAMPLE_DEFAULT="/tmp/pi-github-repos/zai-org/GLM-OCR/examples/source/code.png"
SAMPLE="${1:-$SAMPLE_DEFAULT}"

if [[ ! -e "$SAMPLE" ]]; then
  echo "[ocr] self-test input not found: $SAMPLE" >&2
  echo "[ocr] pass a file path, e.g. ocr doctor /path/to/file.png" >&2
  exit 1
fi

ocr_ensure_setup
ocr_stop_server >/dev/null 2>&1 || true
ocr_start_server_bg

TMP_OUT="$(mktemp -d)"
TMP_CONFIG="$(mktemp)"
cleanup() {
  ocr_stop_server >/dev/null 2>&1 || true
  rm -rf "$TMP_OUT" "$TMP_CONFIG"
}
trap cleanup EXIT

ocr_make_temp_config "$TMP_CONFIG"

CMD=("$OCR_SDK_VENV/bin/glmocr" parse "$SAMPLE" --config "$TMP_CONFIG" --output "$TMP_OUT" --no-layout-vis)
echo "[ocr] self-test running: ${CMD[*]}" >&2
"${CMD[@]}" >/dev/null

STEM="$(basename "$SAMPLE")"
STEM="${STEM%.*}"
MD="$TMP_OUT/$STEM/$STEM.md"
JSON="$TMP_OUT/$STEM/$STEM.json"

if [[ ! -f "$MD" || ! -f "$JSON" ]]; then
  echo "[ocr] self-test failed: expected outputs were not created" >&2
  echo "[ocr] expected: $MD" >&2
  echo "[ocr] expected: $JSON" >&2
  exit 1
fi

echo "ocr_doctor=ok"
echo "sample=$SAMPLE"
echo "model=$OCR_MODEL"
echo "enable_layout=$OCR_ENABLE_LAYOUT"
echo "markdown=$MD"
echo "json=$JSON"
