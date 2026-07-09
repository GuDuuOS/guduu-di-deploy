#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"

log() { echo "[Guduu DI stop] $*"; }

kill_port() {
  local port=$1
  if command -v fuser >/dev/null 2>&1; then
    fuser -k "${port}/tcp" 2>/dev/null || true
  fi
}

for name in web-ui ai-service ibis engine qdrant; do
  pf="$GUDUU_PID_DIR/${name}.pid"
  if [[ -f "$pf" ]]; then
    pid=$(cat "$pf")
    if kill -0 "$pid" 2>/dev/null; then
      log "停止 $name (pid $pid)"
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$pf"
  fi
done

# ibis 使用 gunicorn，父 shell 退出后 PID 文件可能失效
kill_port "${GUDUU_QDRANT_PORT:-6333}"
kill_port "${GUDUU_ENGINE_PORT:-8080}"
kill_port "${GUDUU_IBIS_PORT:-8000}"
kill_port "${GUDUU_UI_PORT:-3100}"
kill_port "${GUDUU_AI_PORT:-5555}"

log "全部服务已停止（部署目录: $GUDUU_DEPLOY_ROOT）"
