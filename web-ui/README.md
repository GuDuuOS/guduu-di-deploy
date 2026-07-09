> ## Guduu DI
>
> **Guduu DI** — 企业级数据智能平台。
>
> 产品名称、Logo 与界面品牌均为 **Guduu DI**。

This is a [Next.js](https://nextjs.org/) project — the Guduu DI Web UI.

## 从源码启动 Web UI

### 完整部署（推荐）

使用项目根目录的部署脚本，详见 [DEPLOY.md](../DEPLOY.md)：

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash ../scripts/setup.sh
bash ../scripts/start.sh
```

### 单独开发 Web UI

前提：其他后端服务已通过部署脚本启动。

**Step 1.** 确认 Node.js >= 18

```bash
node -v
```

**Step 2.** 安装依赖

```bash
yarn
```

**Step 3.** 配置环境变量

```bash
cp .env.local.example .env.local
```

`.env.local` 中 endpoint 应指向已运行的后端服务（默认 `127.0.0.1`）。

**Step 4.** 运行数据库迁移

```bash
yarn migrate
```

**Step 5.** 启动开发服务器

```bash
yarn dev
```

打开 [http://localhost:3000](http://localhost:3000)。

### 切换数据库

默认使用 SQLite。切换 Postgres：

```bash
export DB_TYPE=pg
export PG_URL=postgres://user:password@localhost:5432/dbname
```

切换回 SQLite：

```bash
export DB_TYPE=sqlite
export SQLITE_FILE=./db.sqlite3
```

## 生产构建

```bash
yarn build
yarn start
```

或在部署目录中由 `scripts/setup.sh` 自动完成构建。
