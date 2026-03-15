#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${GLMOCR_REPO_URL:-https://github.com/mejiasd3v/glm-ocr-cli.git}"
REF="${GLMOCR_VERSION:-${GLMOCR_BRANCH:-main}}"
INSTALL_DIR="${GLMOCR_INSTALL_DIR:-$HOME/.local/share/glm-ocr-cli}"
CLI_LINK="${GLMOCR_CLI_LINK:-$HOME/.local/bin/ocr}"
SKILL_LINK="${GLMOCR_SKILL_LINK:-$HOME/.agents/skills/ocr}"
BASH_COMPLETION_LINK="${GLMOCR_BASH_COMPLETION_LINK:-$HOME/.local/share/bash-completion/completions/ocr}"
ZSH_COMPLETION_LINK="${GLMOCR_ZSH_COMPLETION_LINK:-$HOME/.zsh/completions/_ocr}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[glm-ocr-cli] missing required command: $1" >&2
    exit 1
  fi
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_xcode_clt() {
  if xcode-select -p >/dev/null 2>&1; then
    return 0
  fi

  echo "[glm-ocr-cli] installing Xcode Command Line Tools..."
  xcode-select --install || true
  echo "[glm-ocr-cli] finish the Xcode Command Line Tools install, then rerun this command." >&2
  exit 1
}

ensure_homebrew() {
  if have_cmd brew; then
    return 0
  fi

  echo "[glm-ocr-cli] Homebrew not found. Installing Homebrew..."
  NONINTERACTIVE=1 bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi

  need_cmd brew
}

ensure_brew_pkg() {
  local formula="$1"
  if brew list --versions "$formula" >/dev/null 2>&1; then
    return 0
  fi
  echo "[glm-ocr-cli] installing $formula via Homebrew..."
  brew install "$formula"
}

ensure_macos_deps() {
  ensure_xcode_clt
  ensure_homebrew

  ensure_brew_pkg git
  ensure_brew_pkg uv
  ensure_brew_pkg python@3.12
  ensure_brew_pkg poppler

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
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

install_completion_link() {
  local target="$1"
  local link_path="$2"
  mkdir -p "$(dirname "$link_path")"
  backup_if_needed "$link_path" "$target"
  ln -s "$target" "$link_path"
}

need_cmd bash
need_cmd curl

if [[ "$(uname -s)" == "Darwin" ]]; then
  ensure_macos_deps
else
  echo "[glm-ocr-cli] warning: this project is primarily intended for macOS." >&2
  need_cmd git
fi

need_cmd git

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
install_completion_link "$INSTALL_DIR/completions/ocr.bash" "$BASH_COMPLETION_LINK"
install_completion_link "$INSTALL_DIR/completions/_ocr" "$ZSH_COMPLETION_LINK"
chmod +x "$INSTALL_DIR/bin/ocr" "$INSTALL_DIR/install.sh"

echo "[glm-ocr-cli] bootstrapping local OCR environments..."
bash "$INSTALL_DIR/skills/ocr/scripts/setup.sh"

echo "[glm-ocr-cli] installed"
echo "[glm-ocr-cli] ref:   $REF"
echo "[glm-ocr-cli] repo:  $INSTALL_DIR"
echo "[glm-ocr-cli] cli:   $CLI_LINK"
echo "[glm-ocr-cli] skill: $SKILL_LINK"
echo "[glm-ocr-cli] bash completion: $BASH_COMPLETION_LINK"
echo "[glm-ocr-cli] zsh completion:  $ZSH_COMPLETION_LINK"
echo "[glm-ocr-cli] next:  ocr doctor"

echo
if [[ ":${PATH}:" != *":$HOME/.local/bin:"* ]]; then
  echo "[glm-ocr-cli] note: $HOME/.local/bin is not currently on PATH"
  echo "[glm-ocr-cli] add it to your shell profile before using 'ocr' directly"
fi

echo "[glm-ocr-cli] completion tip:"
echo "[glm-ocr-cli]   bash: source $BASH_COMPLETION_LINK"
echo "[glm-ocr-cli]   zsh:  add '$HOME/.zsh/completions' to fpath, then run 'autoload -Uz compinit && compinit'"
