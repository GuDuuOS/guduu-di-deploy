#!/usr/bin/env bash
# Guduu DI — 部署路径解析（源码仓库与运行目录分离）

guduu_source_root() {
  echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

guduu_resolve_deploy_root() {
  local arg_root="${1:-}"
  if [[ -n "$arg_root" ]]; then
    echo "$arg_root"
    return
  fi
  if [[ -n "${GUDUU_DEPLOY_ROOT:-}" ]]; then
    echo "$GUDUU_DEPLOY_ROOT"
    return
  fi
  echo "${HOME}/guduu-di-deploy"
}

guduu_load_env() {
  local deploy_root=$1
  local env_file="$deploy_root/env/.env"
  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
    # 部署目录以命令行/环境变量为准，不被 env 文件覆盖
    GUDUU_DEPLOY_ROOT="$deploy_root"
  fi
}

guduu_paths() {
  local deploy_arg="${1:-}"
  GUDUU_SOURCE_ROOT="$(guduu_source_root)"
  GUDUU_DEPLOY_ROOT="$(guduu_resolve_deploy_root "$deploy_arg")"
  guduu_load_env "$GUDUU_DEPLOY_ROOT"

  GUDUU_APP_ROOT="${GUDUU_DEPLOY_ROOT}/app"
  GUDUU_RUNTIME="${GUDUU_DEPLOY_ROOT}/runtime"
  GUDUU_ENGINE_ROOT="$(guduu_resolve_engine_root)"
  GUDUU_ENV_FILE="${GUDUU_DEPLOY_ROOT}/env/.env"
  GUDUU_PID_DIR="${GUDUU_RUNTIME}/pids"
  GUDUU_LOG_DIR="${GUDUU_RUNTIME}/logs"
}

guduu_resolve_engine_root() {
  if [[ -d "${GUDUU_DEPLOY_ROOT}/semantic-engine/wren-core-legacy" ]] \
    || [[ -d "${GUDUU_DEPLOY_ROOT}/semantic-engine/.git" ]]; then
    echo "${GUDUU_DEPLOY_ROOT}/semantic-engine"
  elif [[ -d "${GUDUU_DEPLOY_ROOT}/wren-engine/wren-core-legacy" ]] \
    || [[ -d "${GUDUU_DEPLOY_ROOT}/wren-engine/.git" ]]; then
    echo "${GUDUU_DEPLOY_ROOT}/wren-engine"
  else
    echo "${GUDUU_DEPLOY_ROOT}/semantic-engine"
  fi
}

guduu_fast_setup_enabled() {
  [[ "${GUDUU_FAST_SETUP:-1}" != "0" ]]
}

guduu_use_prebuilt() {
  [[ "${GUDUU_USE_PREBUILT:-0}" == "1" ]]
}

guduu_online_deploy() {
  [[ ! -d "$GUDUU_SOURCE_ROOT/vendor/prebuilt" ]]
}

guduu_docker_fallback_ok() {
  guduu_use_prebuilt || guduu_online_deploy || [[ "${GUDUU_USE_DOCKER:-0}" == "1" ]]
}

guduu_setup_mirrors() {
  export POETRY_HTTP_TIMEOUT="${POETRY_HTTP_TIMEOUT:-600}"
  export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-600}"
  guduu_setup_yarn_mirror
  guduu_setup_maven_mirror
}

guduu_setup_yarn_mirror() {
  [[ -n "${GUDUU_YARN_REGISTRY:-}" ]] && export YARN_REGISTRY="$GUDUU_YARN_REGISTRY"
}

guduu_setup_maven_mirror() {
  local m2_settings="${GUDUU_M2_SETTINGS:-$GUDUU_RUNTIME/m2/settings.xml}"
  local m2_repo="${GUDUU_M2_REPO:-$GUDUU_RUNTIME/m2/repository}"
  mkdir -p "$(dirname "$m2_settings")" "$m2_repo"
  if [[ -n "${GUDUU_MAVEN_MIRROR:-}" && ! -f "$m2_settings" ]]; then
    cat > "$m2_settings" <<EOF
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0">
  <mirrors>
    <mirror>
      <id>custom-mirror</id>
      <mirrorOf>central</mirrorOf>
      <name>Custom Maven Mirror</name>
      <url>${GUDUU_MAVEN_MIRROR}</url>
    </mirror>
  </mirrors>
</settings>
EOF
  fi
  export MAVEN_OPTS="${MAVEN_OPTS:-} -Dmaven.repo.local=$m2_repo"
  export MVNW_USERNAME= MVNW_PASSWORD=
  [[ -f "$m2_settings" ]] && export MAVEN_CONFIG="$GUDUU_RUNTIME/m2"
}

guduu_engine_jar_path() {
  local root=$1
  find "$root/wren-core-legacy/wren-server/target" -name '*-executable.jar' 2>/dev/null | head -1
}

guduu_docker_available() {
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1
}

guduu_docker_pull() {
  local image=$1
  docker pull "$image" >/dev/null 2>&1 || true
}

guduu_fetch_engine_jar() {
  local tag=$1 engine_root=$2
  local jar target_dir tmp cid jar_path base

  jar=$(guduu_engine_jar_path "$engine_root")
  [[ -n "$jar" ]] && return 0
  guduu_docker_fallback_ok || return 1
  guduu_docker_available || return 1

  local image="${GUDUU_ENGINE_IMAGE:-ghcr.io/canner/wren-engine:${tag}}"
  target_dir="$engine_root/wren-core-legacy/wren-server/target"
  mkdir -p "$target_dir"
  tmp=$(mktemp -d)
  guduu_docker_pull "$image"
  cid=$(docker create "$image" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
  jar_path=$(docker export "$cid" 2>/dev/null | tar -t 2>/dev/null | grep -E 'wren-server.*executable\.jar$' | head -1)
  if [[ -z "$jar_path" ]]; then
    docker rm "$cid" >/dev/null 2>&1 || true
    rm -rf "$tmp"
    return 1
  fi
  docker export "$cid" 2>/dev/null | tar -x -C "$tmp" "$jar_path"
  docker rm "$cid" >/dev/null 2>&1 || true
  base=$(basename "$jar_path")
  cp "$tmp/$jar_path" "$target_dir/$base"
  rm -rf "$tmp"
  [[ -f "$target_dir/$base" ]]
}

guduu_inject_wren_core_from_vendor() {
  local ibis_dir=$1 py=$2
  local vendor="$GUDUU_SOURCE_ROOT/vendor/python"
  local venv_site

  [[ -d "$vendor/wren_core" ]] || return 1
  cd "$ibis_dir"
  poetry env use "$py" 2>/dev/null || true
  if poetry run python -c "import wren_core" 2>/dev/null; then
    return 0
  fi
  venv_site=$(poetry run python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) || return 1
  cp -a "$vendor/wren_core" "$venv_site/"
  cp -a "$vendor/wren_core_py-"*.dist-info "$venv_site/" 2>/dev/null || true
  poetry run python -c "import wren_core" 2>/dev/null
}

guduu_copy_bundled_qdrant() {
  local dest=$1
  local bundled="$GUDUU_SOURCE_ROOT/vendor/bin/qdrant"
  [[ -x "$bundled" ]] || return 1
  mkdir -p "$(dirname "$dest")"
  cp "$bundled" "$dest"
  chmod +x "$dest"
  [[ -x "$dest" ]]
}

guduu_download_qdrant() {
  local dest=$1
  local version="${GUDUU_QDRANT_VERSION:-v1.15.0}"
  local arch asset url tmp

  case "$(uname -m)" in
    x86_64) arch=x86_64-unknown-linux-gnu ;;
    aarch64) arch=aarch64-unknown-linux-gnu ;;
    *) echo "[Guduu DI setup] ERROR: 不支持的 CPU 架构: $(uname -m)" >&2; return 1 ;;
  esac

  asset="qdrant-${arch}.tar.gz"
  url="https://github.com/qdrant/qdrant/releases/download/${version}/${asset}"
  tmp=$(mktemp -d)
  mkdir -p "$(dirname "$dest")"

  echo "[Guduu DI setup] 下载 Qdrant ${version} ..." >&2
  if ! curl -fsSL --connect-timeout 30 --retry 3 "$url" -o "$tmp/qdrant.tar.gz"; then
    rm -rf "$tmp"
    return 1
  fi
  tar -xzf "$tmp/qdrant.tar.gz" -C "$tmp"
  if [[ -f "$tmp/qdrant" ]]; then
    cp "$tmp/qdrant" "$dest"
  elif [[ -f "$tmp/qdrant/qdrant" ]]; then
    cp "$tmp/qdrant/qdrant" "$dest"
  else
    rm -rf "$tmp"
    return 1
  fi
  chmod +x "$dest"
  rm -rf "$tmp"
  [[ -x "$dest" ]]
}

guduu_build_wren_core_py() {
  local ibis_dir=$1 py=$2
  local core_py_dir="$GUDUU_ENGINE_ROOT/wren-core-py"
  local wheel

  [[ -d "$core_py_dir" ]] || return 1
  command -v cargo >/dev/null 2>&1 || {
    echo "[Guduu DI setup] ERROR: 构建 wren_core 需要 Rust（cargo）" >&2
    return 1
  }

  echo "[Guduu DI setup] 编译 wren-core-py（Rust + maturin，需联网）..." >&2
  (
    cd "$core_py_dir"
    poetry install --no-root
    poetry run maturin build --release
  ) || return 1

  wheel=$(find "$core_py_dir/target/wheels" -name 'wren_core_py-*.whl' 2>/dev/null | head -1)
  [[ -n "$wheel" ]] || return 1

  cd "$ibis_dir"
  poetry env use "$py" 2>/dev/null || true
  poetry run pip install --force-reinstall "$wheel"
  poetry run python -c "import wren_core"
}

guduu_restore_poetry_venv() {
  local name=$1 dest_dir=$2 py=$3
  local src="$GUDUU_SOURCE_ROOT/vendor/prebuilt/$name/.venv"
  local check="${4:-import fastapi}"

  [[ -d "$src/bin" ]] || return 1
  cd "$dest_dir"
  poetry config virtualenvs.in-project true --local 2>/dev/null || true
  rm -rf .venv
  cp -a "$src" .venv
  chmod -R u+w .venv 2>/dev/null || true
  poetry env use "$py" 2>/dev/null || poetry env use .venv/bin/python 2>/dev/null || true
  poetry run python -c "$check" 2>/dev/null
}

guduu_restore_web_ui_prebuilt() {
  local dst="$GUDUU_APP_ROOT/web-ui"
  local src="$GUDUU_SOURCE_ROOT/vendor/prebuilt/web-ui"
  [[ -d "$src/node_modules" && -f "$src/.next/BUILD_ID" ]] || return 1
  mkdir -p "$dst"
  rsync -a "$src/node_modules/" "$dst/node_modules/"
  rsync -a "$src/.next/" "$dst/.next/"
  guduu_web_ui_deps_ok "$dst"
}

guduu_web_ui_deps_ok() {
  local ui=${1:-$GUDUU_APP_ROOT/web-ui}
  [[ -f "$ui/.next/BUILD_ID" ]] \
    && [[ -f "$ui/node_modules/@apollo/client/package.json" ]] \
    && [[ -f "$ui/node_modules/next/package.json" ]]
}

guduu_bundled_node20_dir() {
  local bundled="$GUDUU_SOURCE_ROOT/vendor/node20/bin"
  [[ -x "$bundled/node" ]] && echo "$bundled"
}

guduu_has_prebuilt_web_ui() {
  [[ -d "$GUDUU_SOURCE_ROOT/vendor/prebuilt/web-ui/node_modules" ]] \
    && [[ -f "$GUDUU_SOURCE_ROOT/vendor/prebuilt/web-ui/.next/BUILD_ID" ]]
}

guduu_export_node_path() {
  local node_bin_dir
  node_bin_dir=$(guduu_node_bin_dir 2>/dev/null || true)
  if [[ -n "$node_bin_dir" ]]; then
    export PATH="$node_bin_dir:$PATH"
    return 0
  fi
  command -v node >/dev/null 2>&1
}

guduu_inject_wren_core() {
  local tag=$1 ibis_dir=$2 py=$3
  local image venv_site tmp cid src_base arch so_name

  cd "$ibis_dir"
  poetry env use "$py" 2>/dev/null || true
  if poetry run python -c "import wren_core" 2>/dev/null; then
    return 0
  fi
  guduu_docker_fallback_ok || return 1
  guduu_docker_available || return 1

  image="${GUDUU_IBIS_IMAGE:-ghcr.io/canner/wren-engine-ibis:${tag}}"
  venv_site=$(poetry run python -c "import site; print(site.getsitepackages()[0])" 2>/dev/null) || return 1
  arch=$(uname -m)
  case "$arch" in
    x86_64) so_name="wren_core.cpython-311-x86_64-linux-gnu.so" ;;
    aarch64) so_name="wren_core.cpython-311-aarch64-linux-gnu.so" ;;
    *) return 1 ;;
  esac

  tmp=$(mktemp -d)
  src_base="app/.venv/lib/python3.11/site-packages"
  guduu_docker_pull "$image"
  cid=$(docker create "$image" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
  docker export "$cid" 2>/dev/null | tar -x -C "$tmp" \
    "$src_base/wren_core" \
    "$src_base/wren_core_py-0.1.0.dist-info" 2>/dev/null || true
  docker rm "$cid" >/dev/null 2>&1 || true

  if [[ ! -f "$tmp/$src_base/wren_core/$so_name" ]]; then
    rm -rf "$tmp"
    return 1
  fi
  cp -a "$tmp/$src_base/wren_core" "$venv_site/"
  cp -a "$tmp/$src_base/wren_core_py-"*.dist-info "$venv_site/"
  rm -rf "$tmp"
  poetry run python -c "import wren_core" 2>/dev/null
}

guduu_fetch_qdrant_from_image() {
  local dest=$1
  guduu_docker_fallback_ok || return 1
  guduu_docker_available || return 1

  local image="${GUDUU_QDRANT_IMAGE:-qdrant/qdrant:v1.15.0}"
  local tmp cid
  mkdir -p "$(dirname "$dest")"
  tmp=$(mktemp -d)
  guduu_docker_pull "$image"
  cid=$(docker create "$image" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
  docker export "$cid" 2>/dev/null | tar -x -C "$tmp" qdrant/qdrant 2>/dev/null || true
  docker rm "$cid" >/dev/null 2>&1 || true
  if [[ -f "$tmp/qdrant/qdrant" ]]; then
    cp "$tmp/qdrant/qdrant" "$dest"
    chmod +x "$dest"
    rm -rf "$tmp"
    return 0
  fi
  rm -rf "$tmp"
  return 1
}

guduu_parallel_enabled() {
  [[ "${GUDUU_PARALLEL_SETUP:-1}" != "0" ]]
}

guduu_parallel_begin() {
  GUDUU_PARALLEL_PIDS=()
  GUDUU_PARALLEL_NAMES=()
  mkdir -p "$GUDUU_LOG_DIR" "$GUDUU_PID_DIR"
}

guduu_parallel_run() {
  local name=$1
  shift
  local log="$GUDUU_LOG_DIR/setup-${name}.log"
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  : >"$log"
  (
    export GUDUU_DEPLOY_ROOT PY_AI PY_IBIS
    # shellcheck disable=SC1090
    source "$lib_dir/common.sh"
    # shellcheck disable=SC1090
    source "$lib_dir/setup-steps.sh"
    guduu_paths "$GUDUU_DEPLOY_ROOT"
    guduu_setup_mirrors
    "$@"
  ) >>"$log" 2>&1 &
  GUDUU_PARALLEL_PIDS+=("$!")
  GUDUU_PARALLEL_NAMES+=("$name")
}

guduu_parallel_wait() {
  local i failed=0
  for i in "${!GUDUU_PARALLEL_PIDS[@]}"; do
    if ! wait "${GUDUU_PARALLEL_PIDS[$i]}"; then
      echo "[Guduu DI setup] ERROR: 步骤失败: ${GUDUU_PARALLEL_NAMES[$i]} (见 $GUDUU_LOG_DIR/setup-${GUDUU_PARALLEL_NAMES[$i]}.log)" >&2
      failed=1
    fi
  done
  return "$failed"
}

guduu_sync_source() {
  local src="$GUDUU_SOURCE_ROOT"
  local dst="$GUDUU_APP_ROOT"
  mkdir -p "$dst"
  rsync -a --delete \
    --exclude node_modules \
    --exclude .next \
    --exclude .venv \
    --exclude out \
    --exclude build \
    --exclude runtime \
    --exclude semantic-engine \
    --exclude wren-engine \
    --exclude .git \
    --exclude .github \
    --exclude .claude \
    --exclude '*.sqlite3' \
    --exclude '*.sqlite' \
    "$src/" "$dst/"
}

guduu_download_node20() {
  local dest="$GUDUU_RUNTIME/node20"
  local version="${GUDUU_NODE20_VERSION:-20.18.1}"
  local arch tarball url tmp extracted

  case "$(uname -m)" in
    x86_64) arch=linux-x64 ;;
    aarch64) arch=linux-arm64 ;;
    *) echo "[Guduu DI setup] ERROR: 不支持的 CPU 架构: $(uname -m)" >&2; return 1 ;;
  esac

  tarball="node-v${version}-${arch}.tar.xz"
  url="https://nodejs.org/dist/v${version}/${tarball}"
  tmp=$(mktemp -d)
  extracted="node-v${version}-${arch}"

  echo "[Guduu DI setup] 下载 Node.js ${version}（web-ui 需 Node 20 编译 better-sqlite3）..." >&2
  if ! curl -fsSL --connect-timeout 30 --retry 3 "$url" -o "$tmp/node.tar.xz"; then
    rm -rf "$tmp"
    return 1
  fi
  tar -xJf "$tmp/node.tar.xz" -C "$tmp"
  rm -rf "$dest"
  mv "$tmp/$extracted" "$dest"
  rm -rf "$tmp"
  [[ -x "$dest/bin/node" ]]
}

guduu_node_bin_dir() {
  local bundled
  bundled=$(guduu_bundled_node20_dir 2>/dev/null || true)
  if [[ -n "$bundled" ]]; then
    mkdir -p "$GUDUU_RUNTIME/node20"
    if [[ ! -x "$GUDUU_RUNTIME/node20/bin/node" ]]; then
      rsync -a "$GUDUU_SOURCE_ROOT/vendor/node20/" "$GUDUU_RUNTIME/node20/"
    fi
    echo "$GUDUU_RUNTIME/node20/bin"
    return
  fi
  local node20="$GUDUU_RUNTIME/node20/bin"
  if [[ -x "$node20/node" ]]; then
    echo "$node20"
    return
  fi
  if command -v node >/dev/null 2>&1; then
    local major
    major=$(node -v | sed 's/v//' | cut -d. -f1)
    if [[ "$major" -eq 20 ]]; then
      dirname "$(command -v node)"
      return
    fi
  fi
  if guduu_download_node20; then
    echo "$GUDUU_RUNTIME/node20/bin"
    return
  fi
  echo "[Guduu DI setup] ERROR: 需要 Node.js 20（better-sqlite3 不兼容 Node 21+）" >&2
  return 1
}

guduu_poetry_install() {
  local py=$1
  poetry env use "$py" 2>/dev/null || true
  export POETRY_HTTP_TIMEOUT="${POETRY_HTTP_TIMEOUT:-600}"
  export PIP_DEFAULT_TIMEOUT="${PIP_DEFAULT_TIMEOUT:-600}"
  poetry install -v || {
    echo "[Guduu DI setup] poetry install 失败，10 秒后重试 ..." >&2
    sleep 10
    poetry install -v
  }
}

guduu_python() {
  local version="${1:-3.12}"
  if command -v "python${version}" >/dev/null 2>&1; then
    echo "python${version}"
  elif [[ "$version" == "3.12" ]] && command -v python3 >/dev/null 2>&1; then
    echo python3
  else
    return 1
  fi
}
