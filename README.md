# Guduu DI — 国外服务器在线部署版

<p align="center">
  <img src="./gudu-logo.svg" width="120" alt="Guduu DI Logo">
</p>

<p align="center">
  <strong style="font-size: 1.5em">Guduu DI</strong><br>
  <em style="font-size: 1.1em">Data Intelligence</em>
</p>

> 用自然语言提问，生成 SQL、图表与 BI 洞察。**纯源码精简包，国外服务器在线部署。**

本目录 `guduu-di-online` 面向**国外服务器**（约 **90 MB 源码**），不含预编译二进制；`setup.sh` 会在线下载/编译：

| 组件 | setup 阶段 |
|------|-----------|
| Java 引擎 JAR | Maven 编译 |
| wren_core | Rust 编译（需 cargo） |
| Qdrant | GitHub Releases 下载 |
| Node.js 20 | nodejs.org 下载 |
| Python 依赖 | Poetry install |
| web-ui | yarn install + build |

直连官方源（PyPI / npm / Maven Central），无需代理或镜像。

## 快速开始

```bash
cd guduu-di-online

sudo bash scripts/install-prereqs.sh
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/setup.sh          # 首次约 25–40 分钟

vim /var/guduu-di/env/.env     # 填入 OPENAI_API_KEY
bash scripts/start.sh
```

浏览器访问：**http://\<服务器IP\>:3100**

## 与离线版对比

| 项目 | `guduu-di`（离线版） | `guduu-di-online`（本目录） |
|------|---------------------|----------------------------|
| 体积 | ~5 GB | ~90 MB |
| 网络 | 可离线部署 | 需联网下载依赖 |
| 首次部署 | 2–5 分钟 | 25–40 分钟 |

## 文档

- [DEPLOY.md](./DEPLOY.md) — 部署指南
- [DEVELOP.md](./DEVELOP.md) — 开发指南

## 打包交付

```bash
bash scripts/pack-online.sh    # 生成 tar.gz
```

## 运维

```bash
export GUDUU_DEPLOY_ROOT=/var/guduu-di
bash scripts/status.sh
bash scripts/stop.sh
bash scripts/start.sh
```
