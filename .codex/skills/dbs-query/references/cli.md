# DBS CLI

从仓库根目录执行：

```bash
DBS=.codex/skills/dbs-query/dbs.py
```

以下示例中的 `$DBS` 表示上述命令前缀。自动化场景可追加全局参数 `--compact` 获取单行 JSON。

## 认证

先在 `config/dbs-config.json` 配好 URL 和用户名，然后交互输入密码：

```bash
$DBS auth login
$DBS auth status
$DBS auth logout
```

自定义 Archery 站点：

```bash
$DBS auth login --site customer-private
```

临时覆盖配置时仍可传 `--base-url` 和 `-u`；登录成功后会同步更新对应站点配置。

`-p/--password` 仅用于隔离测试，帮助信息中不展示。AI 不使用该参数，避免密码进入命令历史和工具输出。

## 发现实例

```bash
$DBS instance list
$DBS instance list --db-type mysql
$DBS instance list --refresh
```

首次请求从 `/group/user_all_instances/?tag_codes[]=can_read` 获取并缓存，输出 `from_cache: false`；后续输出 `from_cache: true`。

## 发现数据库

优先通过实例 ID 选择：

```bash
$DBS database list --instance-id 80
$DBS database list --instance-id 80 --refresh
```

也可使用完整实例名：

```bash
$DBS database list --instance-name "示例生产MySQL"
```

`--refresh-instances` 会在选择实例前刷新实例缓存。

## Target

Target 将站点、实例、数据库和 schema 固定为一个可复用别名：

```bash
$DBS target add example-prod-data \
  --instance-id 80 \
  --database example-data \
  --description "示例生产数据中心库" \
  --alias "示例 DBS" \
  --alias "示例数据中台"

$DBS target list
$DBS target list --search "示例数据中台"
$DBS target show example-prod-data
$DBS target remove example-prod-data
```

PostgreSQL 可增加 schema：

```bash
$DBS target add example-prod-pg \
  --instance-id 81 \
  --database example-data \
  --schema public
```

Target 创建时会验证实例和数据库确实属于当前用户的可读资源。使用 `--replace` 才能覆盖同名 Target。

## 表结构

```bash
$DBS desc --target example-prod-data example_table
```

## 查询

自动组装 SELECT：

```bash
$DBS query \
  --target example-prod-data \
  --table example_table \
  --columns id,status,created_at \
  --where "id = 100" \
  --limit 1
```

完整 SQL：

```bash
$DBS query \
  --target example-prod-data \
  --sql "SELECT id, status FROM example_table ORDER BY id DESC" \
  --limit 20
```

复杂 SQL 无法识别真实表名时补充：

```bash
$DBS query \
  --target example-prod-data \
  --table example_table \
  --sql "WITH latest AS (...) SELECT * FROM latest" \
  --limit 20
```

默认输出会回显 Target 和 Archery 结果。只有调试接口时才使用 `--raw`。

## 常见错误码

| 错误码 | 处理 |
| --- | --- |
| `AUTH_REQUIRED` | 让用户重新交互登录 |
| `USERNAME_REQUIRED` | 在 `config/dbs-config.json` 的站点中填写 `username` |
| `SITE_NOT_FOUND` | 使用 `auth login --site --base-url` 配置站点 |
| `INSTANCE_NOT_FOUND` | 刷新实例列表一次，仍不存在则让用户重新选择 |
| `DATABASE_NOT_FOUND` | 刷新该实例数据库列表一次，仍不存在则让用户重新选择 |
| `TARGET_NOT_FOUND` | 运行 `target list` 或创建 Target |
| `TARGET_EXISTS` | 不自动覆盖；确认后使用 `--replace` |
| `UNSUPPORTED_DB_TYPE` | 当前只支持 MySQL、PostgreSQL SQL 查询 |
| `QUERY_REJECTED` | 改为单条只读 SELECT，不能绕过校验 |
| `ARCHERY_ERROR` | 展示脱敏后的服务端消息，不盲目重试 |
