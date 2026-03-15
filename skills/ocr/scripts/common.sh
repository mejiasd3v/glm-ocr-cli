#!/usr/bin/env bash
set -euo pipefail

OCR_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OCR_REPO_DIR="$(cd "$OCR_SKILL_DIR/../.." && pwd)"
OCR_MLX_VENV="$OCR_SKILL_DIR/.venv-mlx"
OCR_SDK_VENV="$OCR_SKILL_DIR/.venv-sdk"
OCR_RUNTIME_DIR="$OCR_SKILL_DIR/.runtime"
OCR_HOST="${GLMOCR_HOST:-127.0.0.1}"
OCR_PORT="${GLMOCR_PORT:-8080}"
OCR_MODEL="${GLMOCR_MODEL:-mlx-community/GLM-OCR-bf16}"
OCR_SERVER_LOG="$OCR_RUNTIME_DIR/server.log"
OCR_SERVER_PID_FILE="$OCR_RUNTIME_DIR/server.pid"
OCR_HEALTH_TIMEOUT="${GLMOCR_HEALTH_TIMEOUT:-90}"
OCR_ENABLE_LAYOUT="${GLMOCR_ENABLE_LAYOUT:-0}"

ocr_need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ocr] missing required command: $1" >&2
    exit 1
  fi
}

ocr_server_running() {
  nc -z "$OCR_HOST" "$OCR_PORT" >/dev/null 2>&1
}

ocr_pid_running() {
  if [[ -f "$OCR_SERVER_PID_FILE" ]]; then
    local pid
    pid="$(cat "$OCR_SERVER_PID_FILE" 2>/dev/null || true)"
    [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1
  else
    return 1
  fi
}

ocr_ensure_runtime_dir() {
  mkdir -p "$OCR_RUNTIME_DIR"
}

ocr_mlx_ready() {
  [[ -x "$OCR_MLX_VENV/bin/mlx_vlm.server" ]]
}

ocr_sdk_ready() {
  [[ -x "$OCR_SDK_VENV/bin/glmocr" ]]
}

ocr_ensure_setup() {
  if ocr_mlx_ready && ocr_sdk_ready; then
    return 0
  fi

  echo "[ocr] first run: installing local OCR environments..." >&2
  bash "$OCR_SKILL_DIR/scripts/setup.sh" >&2
}

ocr_wait_for_server() {
  local waited=0
  while (( waited < OCR_HEALTH_TIMEOUT )); do
    if ocr_server_running; then
      return 0
    fi
    sleep 1
    waited=$((waited + 1))
  done

  echo "[ocr] server did not become ready within ${OCR_HEALTH_TIMEOUT}s" >&2
  if [[ -f "$OCR_SERVER_LOG" ]]; then
    echo "[ocr] last server log lines:" >&2
    tail -n 40 "$OCR_SERVER_LOG" >&2 || true
  fi
  return 1
}

ocr_start_server_bg() {
  ocr_ensure_runtime_dir

  if ocr_server_running; then
    echo "[ocr] server already running at ${OCR_HOST}:${OCR_PORT}" >&2
    return 0
  fi

  if ocr_pid_running; then
    echo "[ocr] cleaning stale server state" >&2
    rm -f "$OCR_SERVER_PID_FILE"
  fi

  echo "[ocr] starting background server on ${OCR_HOST}:${OCR_PORT} model=${OCR_MODEL}" >&2
  nohup "$OCR_MLX_VENV/bin/mlx_vlm.server" \
    --model "$OCR_MODEL" \
    --host "$OCR_HOST" \
    --port "$OCR_PORT" \
    --trust-remote-code \
    >"$OCR_SERVER_LOG" 2>&1 &

  echo $! > "$OCR_SERVER_PID_FILE"
  ocr_wait_for_server
}

ocr_stop_server() {
  local pid=""
  if [[ -f "$OCR_SERVER_PID_FILE" ]]; then
    pid="$(cat "$OCR_SERVER_PID_FILE" 2>/dev/null || true)"
  fi

  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    kill "$pid" || true
    echo "[ocr] stopped server pid $pid" >&2
  elif [[ -n "$pid" ]]; then
    echo "[ocr] server pid not running" >&2
  else
    echo "[ocr] no pid file found" >&2
  fi

  local waited=0
  while ocr_server_running && (( waited < 20 )); do
    sleep 1
    waited=$((waited + 1))
  done

  if ocr_server_running && command -v lsof >/dev/null 2>&1; then
    local pids
    pids="$(lsof -tiTCP:"$OCR_PORT" -sTCP:LISTEN 2>/dev/null | tr '\n' ' ')"
    if [[ -n "$pids" ]]; then
      echo "[ocr] force-stopping lingering listener(s) on port $OCR_PORT: $pids" >&2
      kill $pids || true
      sleep 2
    fi
  fi

  rm -f "$OCR_SERVER_PID_FILE"
}

ocr_print_config() {
  echo "skill_dir=$OCR_SKILL_DIR"
  echo "repo_dir=$OCR_REPO_DIR"
  echo "runtime_dir=$OCR_RUNTIME_DIR"
  echo "host=$OCR_HOST"
  echo "port=$OCR_PORT"
  echo "model=$OCR_MODEL"
  echo "enable_layout=$OCR_ENABLE_LAYOUT"
  echo "health_timeout=$OCR_HEALTH_TIMEOUT"
  echo "mlx_env=$OCR_MLX_VENV"
  echo "sdk_env=$OCR_SDK_VENV"
  echo "server_log=$OCR_SERVER_LOG"
}

ocr_print_status() {
  ocr_print_config

  if ocr_mlx_ready; then
    echo "mlx_env_ready=yes"
  else
    echo "mlx_env_ready=no"
  fi

  if ocr_sdk_ready; then
    echo "sdk_env_ready=yes"
  else
    echo "sdk_env_ready=no"
  fi

  if ocr_server_running; then
    echo "server=running"
  else
    echo "server=stopped"
  fi

  if [[ -f "$OCR_SERVER_PID_FILE" ]]; then
    echo "server_pid=$(cat "$OCR_SERVER_PID_FILE" 2>/dev/null || true)"
  fi

  if ! ocr_mlx_ready || ! ocr_sdk_ready; then
    echo "hint=run 'ocr install' to bootstrap local environments"
  elif ! ocr_server_running; then
    echo "hint=run 'ocr doctor' or parse a file with 'ocr <file> --stdout'"
  fi
}

ocr_print_models() {
  cat <<EOF
recommended_model=mlx-community/GLM-OCR-bf16

available_presets:
- mlx-community/GLM-OCR-bf16   # recommended default; best quality/stability
- mlx-community/GLM-OCR-8bit  # lighter memory usage; experimental
- mlx-community/GLM-OCR-4bit  # smallest footprint; most experimental

overrides:
- GLMOCR_MODEL=<huggingface-model-id>
- GLMOCR_PORT=<port>
- GLMOCR_HOST=<host>
- GLMOCR_ENABLE_LAYOUT=1

examples:
- GLMOCR_MODEL=mlx-community/GLM-OCR-8bit ocr ./file.pdf --stdout
- GLMOCR_ENABLE_LAYOUT=1 ocr ./file.pdf --stdout
- GLMOCR_PORT=8081 ocr server
EOF
}

ocr_make_temp_config() {
  local config_path="$1"
  cat > "$config_path" <<EOF
pipeline:
  enable_layout: ${OCR_ENABLE_LAYOUT}
  maas:
    enabled: false
  ocr_api:
    api_host: ${OCR_HOST}
    api_port: ${OCR_PORT}
    model: ${OCR_MODEL}
    api_path: /chat/completions
    verify_ssl: false
EOF
}
