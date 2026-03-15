#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ocr_ensure_setup
ocr_start_server_bg

echo "[ocr] server ready at ${OCR_HOST}:${OCR_PORT}"
echo "[ocr] log: $OCR_SERVER_LOG"
