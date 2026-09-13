# 配置与本地状态

## 需要手工维护的配置

统一编辑仓库文件（只包含非敏感配置）：

```text
.codex/skills/dbs-query/config/dbs-config.json
```

CLI 默认自动读取该文件。其他部署方式可使用全局参数 `--config <path>` 或环境变量 `DBS_CONFIG_FILE` 指向另一份配置。

完整结构示例：

```json
{
  "version": 1,
  "default_site": "poit",
  "sites": {
    "poit": {
      "base_url": "https://dbs.poi-t.cn",
      "username": "your-poit-account"
    },
    "customer-private": {
      "base_url": "https://dbs.customer.example.com",
      "username": "your-customer-account"
    }
  },
  "targets": {
    "jianhui-prod-data": {
      "description": "建晖生产环境数据中心业务库",
      "aliases": ["建晖生产数据中心", "建晖 DBS", "建晖数据中台"],
      "site": "poit",
      "instance_id": 80,
      "instance_name": "建晖生产MySQL",
      "db_type": "mysql",
      "database": "poit-data-center-data",
      "schema": ""
    },
    "customer-app-prod": {
      "description": "客户私有部署应用生产库",
      "aliases": ["客户应用生产库", "客户私有 DBS"],
      "site": "customer-private",
      "instance_id": 12,
      "instance_name": "客户生产MySQL",
      "db_type": "mysql",
      "database": "customer-app",
      "schema": ""
    }
  }
}
```

### sites

每个 Archery/DBS 部署配置一个站点别名：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `base_url` | 是 | 该私有部署的 DBS 地址，不带末尾 `/` |
| `username` | 是 | 该站点默认登录用户名 |

`default_site` 是未传 `--site` 时使用的站点。

同一个 URL 需要使用多个账号时，可配置多个站点别名，例如 `poit-zhangsan`、`poit-lisi`，各自填写用户名。Session 会继续按站点和用户名隔离。

### targets

每个常用数据库配置一个稳定名称：

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `description` | 否 | 业务用途说明，帮助 AI 判断目标 |
| `aliases` | 否 | 客户、系统、项目或口语名称数组，用于搜索 |
| `site` | 是 | `sites` 中的站点别名 |
| `instance_id` | 是 | 实例发现接口返回的 ID |
| `instance_name` | 是 | Archery 实例完整名称 |
| `db_type` | 是 | 当前 SQL Target 支持 `mysql`、`pgsql` |
| `database` | 是 | 数据库名称 |
| `schema` | 否 | PostgreSQL 常用 `public`，MySQL 通常为空 |

Target 名称只能使用字母、数字、点、下划线和连字符。可以直接编辑 JSON，也可以用 `target add` 创建；覆盖同名 Target 必须显式传 `--replace`。

## 用户目录密码配置

CLI 默认从当前用户主目录读取 `.dbs_config.json`：macOS/Linux 为 `~/.dbs_config.json`，Windows 为 `%USERPROFILE%\.dbs_config.json`。也可以通过全局参数 `--secrets <path>` 或环境变量 `DBS_SECRET_FILE` 覆盖路径。

文件示例：

```json
{
  "version": 1,
  "sites": {
    "poit": {
      "password": "your-password"
    }
  }
}
```

该文件只在用户目录维护，禁止提交到项目。macOS/Linux 权限应为 `0600`；Windows 使用当前用户目录并依赖用户文件权限。查询类命令在 Session 不存在时会自动使用该密码登录并保存 Session。

## 禁止写入共享配置的内容

配置文件可能进入 Git，因此只保存 URL、用户名和数据库定位信息。禁止写入密码、Cookie、Session ID 或 CSRF Token。

## 自动维护的敏感状态

登录态与资源缓存仍位于 `~/.dbs-cli`，无需手工编辑：

```text
~/.dbs-cli/
├── cache/
│   └── <site>-<username>-<hash>.json
└── sessions/
    └── <site>-<username>-<hash>.json
```

- Session 文件包含 CSRF Token 和 Session ID，权限为 `0600`。
- 缓存按 `site + username` 隔离。
- `instance list` 首次获取实例，后续使用缓存；`--refresh` 强制刷新。
- `database list` 仅加载指定实例的数据库，避免遍历所有实例。
- 权限变化或资源不存在时最多显式刷新一次。
