#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"

check() {
  local name=$1 port=$2
  local pf="$GUDUU_PID_DIR/${name}.pid"
  local pid="—" state="stopped"
  if [[ -f "$pf" ]]; then
    pid=$(cat "$pf")
    kill -0 "$pid" 2>/dev/null && state="running" || state="dead"
  fi
  local port_ok="down"
  (echo >/dev/tcp/127.0.0.1/"$port") 2>/dev/null && port_ok="up" || true
  printf "  %-12s pid=%-8s state=%-8s port:%s=%s\n" "$name" "$pid" "$state" "$port" "$port_ok"
}

echo "Guduu DI — 服务状态"
echo "  部署目录: $GUDUU_DEPLOY_ROOT"
check qdrant     "${GUDUU_QDRANT_PORT:-6333}"
check engine     "${GUDUU_ENGINE_PORT:-8080}"
check ibis       "${GUDUU_IBIS_PORT:-8000}"
check ai-service "${GUDUU_AI_PORT:-5555}"
check web-ui     "${GUDUU_UI_PORT:-3100}"
