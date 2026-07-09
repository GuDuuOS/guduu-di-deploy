#!/usr/bin/env bash
# Guduu DI — systemd 前台托管：启动后轮询 web-ui 进程，退出后由 systemd 自动重启
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

guduu_paths "${1:-}"

bash "$SCRIPT_DIR/start.sh" "$GUDUU_DEPLOY_ROOT"

pid_file="$GUDUU_PID_DIR/web-ui.pid"
[[ -f "$pid_file" ]] || exit 1
pid=$(cat "$pid_file")
kill -0 "$pid" 2>/dev/null || exit 1

echo "[Guduu DI service] 托管 web-ui pid=$pid，部署目录=$GUDUU_DEPLOY_ROOT"
while kill -0 "$pid" 2>/dev/null; do
  sleep 5
done
echo "[Guduu DI service] web-ui 已退出 (pid=$pid)"
exit 1
