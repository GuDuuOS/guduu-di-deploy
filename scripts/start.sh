#!/usr/bin/env bash
# Guduu DI — 启动全部服务（运行目录与源码仓库分离）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"

UI_PORT="${GUDUU_UI_PORT:-3100}"
AI_PORT="${GUDUU_AI_PORT:-5555}"
ENGINE_PORT="${GUDUU_ENGINE_PORT:-8080}"
IBIS_PORT="${GUDUU_IBIS_PORT:-8000}"
QDRANT_PORT="${GUDUU_QDRANT_PORT:-6333}"
UI_HOST="${GUDUU_UI_HOST:-0.0.0.0}"
LAN_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"

mkdir -p "$GUDUU_PID_DIR" "$GUDUU_LOG_DIR"
export PATH="$GUDUU_RUNTIME/bin:$PATH"

log() { echo "[Guduu DI start] $*"; }
die() { echo "[Guduu DI start] ERROR: $*" >&2; exit 1; }

start_bg() {
  local name=$1 pid_file=$2
  shift 2
  if [[ -f "$pid_file" ]] && kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    log "$name 已在运行 (pid $(cat "$pid_file"))"
    return
  fi
  log "启动 $name ..."
  "$@" >>"$GUDUU_LOG_DIR/${name}.log" 2>&1 &
  echo $! >"$pid_file"
  sleep 2
  if ! kill -0 "$(cat "$pid_file")" 2>/dev/null; then
    log "警告: $name 进程退出，查看 $GUDUU_LOG_DIR/${name}.log"
  fi
}

wait_port() {
  local host=$1 port=$2 name=$3 tries=${4:-60}
  for _ in $(seq 1 "$tries"); do
    if (echo >/dev/tcp/"$host"/"$port") 2>/dev/null; then
      log "$name 就绪 ($host:$port)"
      return 0
    fi
    sleep 1
  done
  die "$name 未在 $host:$port 就绪"
}

[[ -d "$GUDUU_APP_ROOT/web-ui" ]] || die "部署目录未初始化，请先运行: GUDUU_DEPLOY_ROOT='$GUDUU_DEPLOY_ROOT' bash scripts/setup.sh"
[[ -x "$GUDUU_RUNTIME/bin/qdrant" ]] || die "缺少 Qdrant，请先运行 setup.sh"
[[ -d "$GUDUU_ENGINE_ROOT/wren-core-legacy" ]] || die "缺少语义引擎，请先运行 setup.sh"

log "部署目录: $GUDUU_DEPLOY_ROOT"

mkdir -p "$GUDUU_RUNTIME/qdrant-data" "$GUDUU_RUNTIME/etc"
if [[ ! -f "$GUDUU_RUNTIME/etc/qdrant.yaml" ]]; then
  cat > "$GUDUU_RUNTIME/etc/qdrant.yaml" <<EOF
storage:
  storage_path: ${GUDUU_RUNTIME}/qdrant-data
service:
  host: 127.0.0.1
  http_port: ${QDRANT_PORT}
  grpc_port: ${GUDUU_QDRANT_GRPC_PORT:-6334}
EOF
else
  grep -q '^  host:' "$GUDUU_RUNTIME/etc/qdrant.yaml" 2>/dev/null || \
    sed -i "/^service:/a\\  host: 127.0.0.1" "$GUDUU_RUNTIME/etc/qdrant.yaml"
fi

start_bg qdrant "$GUDUU_PID_DIR/qdrant.pid" \
  "$GUDUU_RUNTIME/bin/qdrant" --config-path "$GUDUU_RUNTIME/etc/qdrant.yaml"
wait_port 127.0.0.1 "$QDRANT_PORT" qdrant

JAR=$(find "$GUDUU_ENGINE_ROOT/wren-core-legacy/wren-server/target" -name '*-executable.jar' 2>/dev/null | head -1)
[[ -n "$JAR" ]] || die "未找到 Java 引擎 JAR"

start_bg engine "$GUDUU_PID_DIR/engine.pid" \
  java -Dconfig="$GUDUU_RUNTIME/etc/config.properties" \
  --add-opens=java.base/java.nio=ALL-UNNAMED \
  -jar "$JAR"
wait_port 127.0.0.1 "$ENGINE_PORT" engine

WREN_ENGINE_ENDPOINT="http://127.0.0.1:${ENGINE_PORT}"
IBIS_DIR="$GUDUU_ENGINE_ROOT/ibis-server"
start_bg ibis "$GUDUU_PID_DIR/ibis.pid" \
  bash -c "cd '$IBIS_DIR' && export WREN_ENGINE_ENDPOINT='$WREN_ENGINE_ENDPOINT' && \
    (poetry run python -m fastapi run --port $IBIS_PORT 2>/dev/null \
      || .venv/bin/python -m fastapi run --port $IBIS_PORT)"
wait_port 127.0.0.1 "$IBIS_PORT" ibis

start_bg ai-service "$GUDUU_PID_DIR/ai-service.pid" \
  bash -c "cd '$GUDUU_APP_ROOT/ai-service' && export WREN_AI_SERVICE_PORT='$AI_PORT' QDRANT_HOST=127.0.0.1 CONFIG_PATH='$GUDUU_APP_ROOT/ai-service/config.yaml' && poetry run python -m src.__main__"
wait_port 127.0.0.1 "$AI_PORT" ai-service

guduu_export_node_path || die "缺少 Node.js >= 18"
WEB_UI_NEXT="$GUDUU_APP_ROOT/web-ui/node_modules/.bin/next"
[[ -x "$WEB_UI_NEXT" ]] || die "web-ui 未构建，请先运行 setup.sh"

start_bg web-ui "$GUDUU_PID_DIR/web-ui.pid" \
  bash -c "cd '$GUDUU_APP_ROOT/web-ui' && \
    export PATH='$PATH' \
    WREN_ENGINE_ENDPOINT='http://127.0.0.1:${ENGINE_PORT}' \
    WREN_AI_ENDPOINT='http://127.0.0.1:${AI_PORT}' \
    IBIS_SERVER_ENDPOINT='http://127.0.0.1:${IBIS_PORT}' \
    OTHER_SERVICE_USING_DOCKER=false \
    TELEMETRY_ENABLED='${TELEMETRY_ENABLED:-false}' \
    PORT='$UI_PORT' HOSTNAME='$UI_HOST' TZ=UTC && \
    node node_modules/.bin/next start -H '$UI_HOST' -p '$UI_PORT'"
wait_port 127.0.0.1 "$UI_PORT" web-ui

log "=========================================="
log " Guduu DI 已启动"
log " Web UI:  http://127.0.0.1:${UI_PORT}"
if [[ -n "$LAN_IP" && "$UI_HOST" != "127.0.0.1" ]]; then
  log " 局域网:   http://${LAN_IP}:${UI_PORT}"
fi
log " AI API:  http://127.0.0.1:${AI_PORT}（内网，经 Web UI :${UI_PORT}/api/v1 对外）"
log " 部署目录: $GUDUU_DEPLOY_ROOT"
log " 日志目录: $GUDUU_LOG_DIR"
log "=========================================="
