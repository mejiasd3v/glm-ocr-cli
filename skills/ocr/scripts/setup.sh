#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

ocr_need_cmd uv
ocr_need_cmd python3

echo "[ocr] skill dir: $OCR_SKILL_DIR"

if ! command -v pdftoppm >/dev/null 2>&1; then
  echo "[ocr] warning: pdftoppm not found. PDF support may be limited until Poppler is installed." >&2
  echo "[ocr] install with: brew install poppler" >&2
fi

if [[ ! -x "$OCR_MLX_VENV/bin/mlx_vlm.server" || ! -x "$OCR_MLX_VENV/bin/pip" ]]; then
  echo "[ocr] creating mlx server environment..."
  rm -rf "$OCR_MLX_VENV"
  uv venv --python 3.12 --seed "$OCR_MLX_VENV"
  "$OCR_MLX_VENV/bin/python" -m pip install --upgrade pip setuptools wheel
  "$OCR_MLX_VENV/bin/pip" install "git+https://github.com/Blaizzy/mlx-vlm.git"
else
  echo "[ocr] mlx server environment already exists"
fi

if [[ ! -x "$OCR_SDK_VENV/bin/glmocr" || ! -x "$OCR_SDK_VENV/bin/pip" ]]; then
  echo "[ocr] creating GLM-OCR SDK environment..."
  rm -rf "$OCR_SDK_VENV"
  uv venv --python 3.12 --seed "$OCR_SDK_VENV"
  "$OCR_SDK_VENV/bin/python" -m pip install --upgrade pip setuptools wheel
  "$OCR_SDK_VENV/bin/pip" install "glmocr[selfhosted]" "transformers>=5.3.0"
else
  echo "[ocr] GLM-OCR SDK environment already exists"
fi

echo "[ocr] setup complete"
echo "[ocr] CLI: ocr <file.pdf|image.png> --stdout"
echo "[ocr] manage: ocr status | ocr server | ocr stop | ocr install"
