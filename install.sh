#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${GLMOCR_REPO_URL:-https://github.com/mejiasd3v/glm-ocr-cli.git}"
REF="${GLMOCR_VERSION:-${GLMOCR_BRANCH:-main}}"
INSTALL_DIR="${GLMOCR_INSTALL_DIR:-$HOME/.local/share/glm-ocr-cli}"
CLI_LINK="${GLMOCR_CLI_LINK:-$HOME/.local/bin/ocr}"
SKILL_LINK="${GLMOCR_SKILL_LINK:-$HOME/.agents/skills/ocr}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[glm-ocr-cli] missing required command: $1" >&2
    exit 1
  fi
}

backup_if_needed() {
  local path="$1"
  local target="$2"

  if [[ -L "$path" ]]; then
    local current
    current="$(readlink "$path" || true)"
    if [[ "$current" == "$target" ]]; then
      rm -f "$path"
      return 0
    fi
  fi

  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.bak.$(date +%Y%m%d-%H%M%S)"
    echo "[glm-ocr-cli] backing up existing path: $path -> $backup"
    mv "$path" "$backup"
  fi
}

need_cmd git
need_cmd bash

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[glm-ocr-cli] warning: this project is primarily intended for macOS." >&2
fi

mkdir -p "$(dirname "$INSTALL_DIR")"
if [[ -d "$INSTALL_DIR/.git" ]]; then
  echo "[glm-ocr-cli] updating existing repo in $INSTALL_DIR"
  git -C "$INSTALL_DIR" fetch --tags origin
  git -C "$INSTALL_DIR" checkout "$REF"
  if git -C "$INSTALL_DIR" show-ref --verify --quiet "refs/remotes/origin/$REF"; then
    git -C "$INSTALL_DIR" pull --ff-only origin "$REF"
  fi
else
  if [[ -e "$INSTALL_DIR" ]]; then
    backup_if_needed "$INSTALL_DIR" "$INSTALL_DIR"
  fi
  echo "[glm-ocr-cli] cloning repo to $INSTALL_DIR"
  git clone --branch "$REF" "$REPO_URL" "$INSTALL_DIR"
fi

mkdir -p "$(dirname "$CLI_LINK")" "$(dirname "$SKILL_LINK")"
backup_if_needed "$CLI_LINK" "$INSTALL_DIR/bin/ocr"
backup_if_needed "$SKILL_LINK" "$INSTALL_DIR/skills/ocr"

ln -s "$INSTALL_DIR/bin/ocr" "$CLI_LINK"
ln -s "$INSTALL_DIR/skills/ocr" "$SKILL_LINK"
chmod +x "$INSTALL_DIR/bin/ocr" "$INSTALL_DIR/install.sh"

echo "[glm-ocr-cli] installed"
echo "[glm-ocr-cli] ref:   $REF"
echo "[glm-ocr-cli] repo:  $INSTALL_DIR"
echo "[glm-ocr-cli] cli:   $CLI_LINK"
echo "[glm-ocr-cli] skill: $SKILL_LINK"
echo "[glm-ocr-cli] next:  ocr doctor"

echo
if [[ ":${PATH}:" != *":$HOME/.local/bin:"* ]]; then
  echo "[glm-ocr-cli] note: $HOME/.local/bin is not currently on PATH"
  echo "[glm-ocr-cli] add it to your shell profile before using 'ocr' directly"
fi
