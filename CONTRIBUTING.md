> ## Guduu DI
>
> **Guduu DI** — 企业级数据智能平台。
>
> 产品名称、Logo 与界面品牌均为 **Guduu DI**。

# Contributing Guidelines

*Pull requests, bug reports, and all other forms of contribution are welcomed and highly encouraged!* :octocat:

### Contents

- [Code of Conduct](#book-code-of-conduct)
- [Overview](#mag-overview)
- [Contribution Guide of Different Services](#love_letter-contribution-guide-of-different-services)
- [Creating a New Data Source Connector](#electric_plug-creating-a-new-data-source-connector)

> **This guide serves to set clear expectations for everyone involved with the project so that we can improve it together while also creating a welcoming space for everyone to participate. Following these guidelines will help ensure a positive experience for contributors and maintainers.**

## :book: Code of Conduct

Please review our [Code of Conduct](https://local repository). It is in effect at all times. We expect it to be honored by everyone who contributes to this project. Acting like an asshole will not be tolerated.

## :rocket: Get Started
1. Visit [架构说明](https://docs.guduu.local/oss/overview/how_Guduu DI_works) to understand the architecture of Guduu DI
1. After you understand the architecture of Guduu DI, understand the scope of the services you want to contribute to.
  Check each service's section under [Contribution Guide of Different Services](#love_letter-contribution-guide-of-different-services) to learn how to contribute to each service.
    1. If you are dealing with UI-related tasks, such as adding a dark mode, you only need to contribute to the [Guduu DI Web UI Service](#web-ui-service).
    2. If you are dealing with LLM-related tasks, such as enhancing the prompts used in the LLM pipelines, you only need to contribute to the [Guduu DI AI Service](#ai-service).
    3. If you are working on data-source-related tasks, such as fixing a bug in SQL server connector, you will need to contribute to the [语义查询引擎 Service](#semantic-engine-service).
1. If you are not sure which service to contribute to, please reach out to us in [Discord](https://discord.gg/guduu) or [GitHub Issues](https://local repository).
1. It's possible that you need to contribute to multiple services. For example, if you are adding a new data source, you will need to contribute to the [Guduu DI Web UI Service](#web-ui-service) and [语义查询引擎 Service](#semantic-engine-service). Follow [Guide for Contributing to Multiple Services](#guide-for-contributing-to-multiple-services) to learn how to contribute to multiple services.

## :love_letter: Contribution Guide of Different Services

### Guduu DI AI Service

Guduu DI AI Service is responsible for LLM-related tasks like converting natural language questions into SQL queries and providing step-by-step SQL breakdowns.

To contribute to Guduu DI AI Service, please refer to the [Guduu DI AI Service Contributing Guide](https://local repository)

### Guduu DI Web UI Service

Guduu DI Web UI is the client service of Guduu DI. It is built with Next.js and TypeScript. 
To contribute to Guduu DI Web UI, you can refer to the [guduu-di/web-ui/README.md](https://local repository) file for instructions on how to set up the development environment and run the development server.

### 语义查询引擎 Service
语义查询引擎 is the backbone of the Guduu DI project. The semantic engine for LLMs, bringing business context to AI agents.

To contribute, please refer to [语义查询引擎 Contributing Guide](https://github.com/Guduu-DI/engine/blob/main/ibis-server/docs/CONTRIBUTING.md)

## Guide for Contributing to Multiple Services

使用源码部署脚本启动全部或部分服务。部署目录与源码仓库分离，详见 [DEPLOY.md](./DEPLOY.md)。

```bash
export GUDUU_DEPLOY_ROOT=~/guduu-di-dev
bash scripts/setup.sh
vim ~/guduu-di-dev/env/.env          # 填入 OPENAI_API_KEY
bash scripts/start.sh                # 启动全部服务
```

若只需开发单个模块，可只启动该模块对应的服务，并在 `.env.local` 中将 endpoint 指向已运行的服务。

### 示例：同时开发 Web UI 与语义引擎

1. 用 `scripts/start.sh` 启动除目标模块外的其他服务
2. 在源码目录中单独启动正在开发的模块
3. 在 `web-ui/.env.local` 中配置各服务的 endpoint

```bash
# 开发 Web UI 热更新
cd web-ui
cp .env.local.example .env.local
yarn dev
```

## :electric_plug: Creating a New Data Source Connector

To develop a new data source connector, you'll need to modify both the front-end and back-end of the Guduu DI Web UI, in addition to the 语义查询引擎.

Below is a brief overview of a data source connector:

<img src="./misc/data_source.png" width="400">

The UI is primarily responsible for storing database connection settings, providing an interface for users to input these settings, and submitting them to the Engine, which then connects to the database.

The UI must be aware of the connection details it needs to retain, as specified by the Engine. Therefore, the implementation sequence would be as follows:

- Engine:
  - Implement the new data source (you'll determine what connection information is needed and how it should be passed from the UI).
  - Implement the metadata API for the UI to access.
- UI:
  - Back-End:
    - Safely store the connection information.
    - Provide the connection information to the Engine.
  - Front-End:
    - Prepare an icon for the data source.
    - Set up the form template for users to input the connection information.
    - Update the data source list.

### 语义查询引擎

- To implement a new data source, please refer to [How to Add a New Data Source](https://github.com/Guduu-DI/engine/blob/main/ibis-server/docs/how-to-add-data-source.md).
- After adding a new data source, you can proceed with implementing the metadata API for the UI.

  Here are some previous PRs that introduced new data sources:
    - [Add MSSQL data source](https://github.com/Guduu-DI/engine/pull/631)
    - [Add MySQL data source](https://github.com/Guduu-DI/engine/pull/618)
    - [Add ClickHouse data source](https://github.com/Guduu-DI/engine/pull/648)

### Guduu DI Web UI Guide

We'll describe what should be done in the UI for each new data source. 

If you prefer to learn by example, you can refer to this Trino [issue](https://local repository) and [PR](https://local repository).

#### Backend
1. Define the data source in `web-ui/src/apollo/server/dataSource.ts`
  - define the `toIbisConnectionInfo` and `sensitiveProps` methods

2. Modify the ibis adaptor in `web-ui/src/apollo/server/adaptors/ibisAdaptor.ts`
  - define an ibis connection info type for the new data source
  - set up the `dataSourceUrlMap` for the new data source

3. Modify the repository in `web-ui/src/apollo/server/repositories/projectRepository.ts`
  - define the Guduu DI Web UI connection info type for the new data source 

4. Update the graphql schema in `web-ui/src/apollo/server/schema.ts` so that the new data source can be used in the UI 
  - add the new data source to the `DataSource` enum

5. Update the type definition in `web-ui/src/apollo/server/types/dataSource.ts`
  - add the new data source to the `DataSourceName` enum

#### Frontend
1. Prepare the data source's logo:
   - Image size should be `40 x 40` px
   - Preferably use SVG format
   - Ensure the logo is centered within a `30px` container for consistent formatting

   Example:

   <img src="./misc/logo_template.jpg" width="120">

2. Create the data source form template:
   - In `web-ui/src/components/pages/setup/dataSources`, add a new file named `${dataSource}Properties.tsx`
   - Implement the data source form template in this file

3. Set up the data source template:
   - Navigate to `web-ui/src/utils/dataSourceType.ts`
   - Add new data source image, name, properties
   - Update the necessary files to include the new data source template settings

4. Update the data source list:
   - Add the new data source to the `DATA_SOURCES` enum in `web-ui/src/utils/enum/dataSources.ts`
   - Update relevant files in `web-ui/src/components/pages/setup/` to include the new data source
   - Ensure `web-ui/src/apollo/server/adaptors/ibisAdaptor.ts` handle the new data source

5. Test the new connector:
   - Ensure the new data source appears in the UI
   - Verify that the form works correctly
   - Test the connection to the new data source

