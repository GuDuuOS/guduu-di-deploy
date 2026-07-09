#!/usr/bin/env bash
# Guduu DI — setup 分步函数（可被 setup.sh 串行或并行调用）

guduu_step_log() {
  echo "[Guduu DI setup:${1:-main}] $*"
}

guduu_step_engine_clone() {
  if [[ -d "$GUDUU_ENGINE_ROOT/.git" ]] || [[ -d "$GUDUU_ENGINE_ROOT/ibis-server" ]]; then
    guduu_step_log engine "语义引擎已存在，跳过"
    return 0
  fi

  local local_src=""
  for local_src in \
    "${GUDUU_ENGINE_LOCAL:-}" \
    "$GUDUU_SOURCE_ROOT/semantic-engine" \
    "$GUDUU_SOURCE_ROOT/wren-engine"; do
    [[ -n "$local_src" && -d "$local_src/ibis-server" ]] || continue
    guduu_step_log engine "复制本地语义引擎: $local_src"
    mkdir -p "$GUDUU_ENGINE_ROOT"
    rsync -a "$local_src/" "$GUDUU_ENGINE_ROOT/"
    return 0
  done

  guduu_step_log engine "ERROR: 缺少 semantic-engine/（请确认源码包完整）"
  return 1
}

guduu_step_engine_config() {
  mkdir -p "$GUDUU_RUNTIME/etc/mdl"
  local port="${GUDUU_ENGINE_PORT:-8080}"
  cat > "$GUDUU_RUNTIME/etc/config.properties" <<EOF
node.environment=production
http-server.http.port=${port}
EOF
  if [[ ! -f "$GUDUU_RUNTIME/etc/mdl/sample.json" ]]; then
    echo '{"catalog":"wren","schema":"public","models":[]}' > "$GUDUU_RUNTIME/etc/mdl/sample.json"
  fi
}

guduu_step_engine_jar() {
  local jar
  jar=$(guduu_engine_jar_path "$GUDUU_ENGINE_ROOT")
  if [[ -n "$jar" ]]; then
    guduu_step_log engine "Java 引擎已就绪: $(basename "$jar")"
    return 0
  fi

  guduu_step_log engine "编译 Java 语义引擎（Maven，需联网下载依赖）..."
  (
    cd "$GUDUU_ENGINE_ROOT/wren-core-legacy"
    guduu_setup_maven_mirror
    ./mvnw clean install -DskipTests -P exec-jar \
      -Dmaven.gitcommitid.skip=true -q
  ) || {
    jar=$(guduu_engine_jar_path "$GUDUU_ENGINE_ROOT")
    [[ -n "$jar" ]] && return 0
    guduu_step_log engine "Maven 编译失败，尝试从 Docker 镜像获取 JAR ..."
    guduu_fetch_engine_jar "latest" "$GUDUU_ENGINE_ROOT" || return 1
  }
}

guduu_step_ibis() {
  local py_ibis="${PY_IBIS:?}"
  local ibis_dir="$GUDUU_ENGINE_ROOT/ibis-server"

  cd "$ibis_dir"
  if [[ ! -f .env ]]; then
    cat > .env <<EOF
WREN_ENGINE_ENDPOINT=http://127.0.0.1:${GUDUU_ENGINE_PORT:-8080}
LOG_LEVEL=INFO
EOF
  fi

  if poetry env use "$py_ibis" 2>/dev/null && poetry run python -c "import wren_core, ibis" 2>/dev/null; then
    guduu_step_log ibis "ibis-server 依赖已就绪，跳过"
    return 0
  fi

  if guduu_restore_poetry_venv ibis-server "$ibis_dir" "$py_ibis" "import wren_core, ibis"; then
    guduu_step_log ibis "ibis-server 依赖（离线包 vendor/prebuilt/）已就绪"
    return 0
  fi

  guduu_step_log ibis "安装 ibis-server 依赖（需联网）..."
  guduu_poetry_install "$py_ibis" || return 1
  if ! poetry run python -c "import wren_core, ibis" 2>/dev/null; then
    guduu_inject_wren_core_from_vendor "$ibis_dir" "$py_ibis" \
      || guduu_build_wren_core_py "$ibis_dir" "$py_ibis" \
      || guduu_inject_wren_core "latest" "$ibis_dir" "$py_ibis" \
      || { guduu_step_log ibis "ERROR: wren_core 安装失败（需 Rust、cargo 或 Docker）"; return 1; }
  fi
}

guduu_step_ai_service() {
  local py_ai="${PY_AI:?}"
  cd "$GUDUU_APP_ROOT/ai-service"
  if [[ ! -f config.yaml ]]; then
    cp tools/config/config.example.yaml config.yaml
    sed -i "s|http://localhost:3000|http://127.0.0.1:${GUDUU_UI_PORT:-3100}|g" config.yaml
    sed -i "s|http://localhost:6333|http://127.0.0.1:${GUDUU_QDRANT_PORT:-6333}|g" config.yaml
  fi
  sed -i "s|^  port: .*|  port: ${GUDUU_AI_PORT:-5555}|" config.yaml
  if [[ ! -f .env.dev ]]; then
    cp tools/config/.env.dev.example .env.dev
    echo "OPENAI_API_KEY=${OPENAI_API_KEY:-}" >> .env.dev
  fi
  if poetry env use "$py_ai" 2>/dev/null && poetry run python -c "import fastapi" 2>/dev/null; then
    guduu_step_log ai "ai-service 依赖已就绪，跳过"
    return 0
  fi

  if guduu_restore_poetry_venv ai-service "$GUDUU_APP_ROOT/ai-service" "$py_ai" "import fastapi"; then
    guduu_step_log ai "ai-service 依赖（离线包 vendor/prebuilt/）已就绪"
    return 0
  fi

  guduu_step_log ai "安装 ai-service 依赖（需联网）..."
  guduu_poetry_install "$py_ai"
}

guduu_step_web_ui() {
  if [[ "${GUDUU_SKIP_WEB_UI:-0}" == "1" ]]; then
    guduu_step_log web-ui "跳过 web-ui（GUDUU_SKIP_WEB_UI=1）"
    return 0
  fi

  cd "$GUDUU_APP_ROOT/web-ui"
  cp -f "$GUDUU_SOURCE_ROOT/gudu-logo.svg" public/images/gudu-logo.svg 2>/dev/null || \
    cp -f "$GUDUU_SOURCE_ROOT/../gudu-logo.svg" public/images/gudu-logo.svg 2>/dev/null || true
  cp -f "$GUDUU_SOURCE_ROOT/gudu-logo.svg" public/images/logo.svg 2>/dev/null || \
    cp -f "$GUDUU_SOURCE_ROOT/../gudu-logo.svg" public/images/logo.svg 2>/dev/null || true
  if [[ ! -f .env.local ]]; then
    cp .env.local.example .env.local 2>/dev/null || true
  fi

  if guduu_web_ui_deps_ok && [[ "${GUDUU_FORCE_REBUILD:-0}" != "1" ]]; then
    guduu_step_log web-ui "web-ui 已构建，跳过"
    return 0
  fi

  if [[ "${GUDUU_FORCE_REBUILD:-0}" != "1" ]] && guduu_restore_web_ui_prebuilt; then
    guduu_step_log web-ui "web-ui 构建产物（离线包 vendor/prebuilt/）已就绪"
    return 0
  fi

  if [[ -d node_modules ]] && ! guduu_web_ui_deps_ok; then
    guduu_step_log web-ui "node_modules 不完整，从 vendor/prebuilt 重新恢复 ..."
    rm -rf node_modules .next
    guduu_restore_web_ui_prebuilt && return 0
  fi

  local node_bin_dir
  node_bin_dir=$(guduu_node_bin_dir) || { guduu_step_log web-ui "ERROR: 无法准备 Node.js 20"; return 1; }
  export PATH="$node_bin_dir:$PATH"
  guduu_setup_yarn_mirror
  guduu_step_log web-ui "使用 Node $(node -v)"

  if [[ ! -d node_modules ]] || [[ "${GUDUU_FORCE_REBUILD:-0}" == "1" ]]; then
    [[ "${GUDUU_FORCE_REBUILD:-0}" == "1" ]] && rm -rf node_modules .next 2>/dev/null || true
    guduu_step_log web-ui "yarn install（需联网，含 duckdb 编译）..."
    yarn install --frozen-lockfile 2>/dev/null || yarn install
  fi

  yarn migrate
  if [[ ! -f .next/BUILD_ID ]] || [[ "${GUDUU_FORCE_REBUILD:-0}" == "1" ]]; then
    guduu_step_log web-ui "构建 web-ui ..."
    yarn build
  fi
}

guduu_step_qdrant() {
  local qdrant_bin="$GUDUU_RUNTIME/bin/qdrant"
  if [[ -x "$qdrant_bin" ]]; then
    guduu_step_log qdrant "Qdrant 已就绪，跳过"
    return 0
  fi

  if guduu_copy_bundled_qdrant "$qdrant_bin"; then
    guduu_step_log qdrant "Qdrant（离线包 vendor/bin/）已就绪"
    return 0
  fi

  if guduu_download_qdrant "$qdrant_bin"; then
    guduu_step_log qdrant "Qdrant（GitHub 下载）已就绪"
    return 0
  fi

  if guduu_fetch_qdrant_from_image "$qdrant_bin"; then
    guduu_step_log qdrant "Qdrant（Docker 镜像提取）已就绪"
    return 0
  fi

  guduu_step_log qdrant "ERROR: Qdrant 安装失败（需联网或 Docker）"
  return 1
}
