> ## Guduu DI
>
> **Guduu DI** — 企业级数据智能平台。
>
> 产品名称、Logo 与界面品牌均为 **Guduu DI**。

## How to run e2e test locally

1. Make sure you have start all Guduu DI AI Services. ([How to start](https://local repository))

2. Create a `e2e.config.json` file under `web-ui/e2e` folder and replace all data sources needed values in `./config.ts`.

   ```ts
   // Replace the default test config with your own e2e.config.json
   const defaultTestConfig = {
     bigQuery: {
       projectId: 'Guduu DI',
       datasetId: 'Guduu DI.tpch_sf1',
       // The credential file should be under "web-ui" folder
       // For example: .tmp/credential.json
       credentialPath: 'bigquery-credential-path',
     },
     duckDb: {
       sqlCsvPath: 'https://duckdb.org/data/flights.csv',
     },
     postgreSql: {
       host: 'postgresql-host',
       port: '5432',
       username: 'postgresql-username',
       password: 'postgresql-password',
       database: 'postgresql-database',
       ssl: false,
     },
     mysql: {
       host: 'mysql-host',
       port: '3306',
       username: 'mysql-username',
       password: 'mysql-password',
       database: 'mysql-database',
     },
     sqlServer: {
       host: 'sqlServer-host',
       port: '1433',
       username: 'sqlServer-username',
       password: 'sqlServer-password',
       database: 'sqlServer-database',
     },
     trino: {
       host: 'trino-host',
       port: '8081',
       catalog: 'trino-catalog',
       schema: 'trino-schema',
       username: 'trino-username',
       password: 'trino-password',
     },
   };
   ```

3. Build UI before starting e2e server

   ```bash
   yarn build
   ```

   > Ensure port 3000 is available for E2E testing. Point the AI service UI endpoint at this port (see `.env.dev`) for accurate and reliable test results.

4. Run test

   ```bash
   yarn test:e2e
   ```

   Run test with browser open

   ```bash
   yarn test:e2e --headed
   ```

## How to develop

- Write test with interactive UI mode

  ```bash
  yarn test:e2e --ui
  ```

- Write test with debug mode

  ```bash
  yarn test:e2e --debug
  ```

- Generate test scripts

  ```
  npx playwright codegen http://localhost:3000
  ```
