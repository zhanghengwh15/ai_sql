---
name: db-query
description: 使用 jenkins-tool db-query 对 data-warehouse MySQL 数据库执行查询。触发词："查数据库"、"db-query"、"查表结构"、"查数据"、"执行 SQL"、"DDL"、"表字段"。只读为主，写操作需显式确认。
---
# 数据库查询 Skill（data-warehouse）

通过 `jenkins-tool db-query` CLI 对 data-warehouse 的 MySQL 数据库进行结构化查询。所有输出为 JSON，供 AI 和开发者直接消费。

## 前置条件

1. `jenkins-tool` 已安装并在 PATH 中
2. `~/.jenkins_tool_credentials.json` 已配置数据库连接：

```json
{
  "data-warehouse": {
    "driver": "mysql",
    "host": "test-mysql-rds.poi-t.cn",
    "port": 991,
    "user": "poit-dev-biguser",
    "password": "uT1jK98,sgRa",
    "database": "poit-data-warehouse"
  }
}
```

3. 目标数据库可连接（开发服务器 `test-mysql-rds.poi-t.cn:991`）

## data-warehouse 环境速查

| 配置项 | 值 |
|--------|-----|
| 连接名 | `data-warehouse` |
| Host | `test-mysql-rds.poi-t.cn` |
| Port | `991` |
| User | `poit-dev-biguser` |
| Password | `uT1jK98,sgRa` |
| Database | `poit-data-warehouse` |

## 子命令速查

### ddl — 查看表结构

```bash
jenkins-tool db-query ddl -d data-warehouse -t <table_name>
jenkins-tool db-query ddl -d data-warehouse -t <table_name> --pretty   # 美化输出
```

返回：列信息、索引、外键。

### select — 执行 SELECT 查询

```bash
# 直接传 SQL
jenkins-tool db-query select -d data-warehouse -s "SELECT * FROM <table_name> LIMIT 10"

# 从 stdin 读取（避免 shell 转义）
echo "SELECT * FROM <table_name> WHERE <condition> LIMIT 20" | \
  jenkins-tool db-query select -d data-warehouse

# 自定义返回行数上限
jenkins-tool db-query select -d data-warehouse --limit 50 -s "SELECT * FROM <table_name>"
```

### exec — 执行写操作（需 --confirm）

```bash
# 插入
jenkins-tool db-query exec -d data-warehouse -s \
  "INSERT INTO <table_name> (<column_name>) VALUES ('test')" --confirm

# 更新（必须有 WHERE）
jenkins-tool db-query exec -d data-warehouse -s \
  "UPDATE <table_name> SET <column_name>='new_value' WHERE <id_column>=123" --confirm
```

### ping — 测试连接

```bash
jenkins-tool db-query ping -d data-warehouse
```

## 安全规则（必须遵守）

- **SELECT 必须带 LIMIT**：硬上限 1000 行，避免扫全表
- **写操作必须 --confirm**：`exec` 子命令缺 `--confirm` 会被拒绝
- **UPDATE 必须含 WHERE**：没有 WHERE 子句的 UPDATE 直接拒绝
- **禁止 DELETE / DROP / ALTER / TRUNCATE**：`exec` 安全校验只允许 INSERT 和 UPDATE
- **按需添加过滤条件**：根据目标表结构补充必要的 WHERE 条件

## 常用查询模式

### 1. 快速了解表结构

```bash
jenkins-tool db-query ddl -d data-warehouse -t <table_name> --pretty
```

输出 JSON 包含 `columns`（列名、类型、是否可空、默认值、注释）、`indexes`（索引名、列、是否唯一）、`foreign_keys`。

### 2. 按 ID 查单条记录

```bash
echo "SELECT * FROM <table_name> WHERE <id_column>=10 LIMIT 1" | \
  jenkins-tool db-query select -d data-warehouse
```

### 3. 查最近 N 条记录

```bash
echo "SELECT * FROM <table_name> ORDER BY <id_column> DESC LIMIT 10" | \
  jenkins-tool db-query select -d data-warehouse
```

### 4. 统计数量

```bash
echo "SELECT <group_column>, COUNT(*) AS cnt FROM <table_name> GROUP BY <group_column> LIMIT 100" | \
  jenkins-tool db-query select -d data-warehouse
```

### 5. 按条件筛选记录

```bash
echo "SELECT * FROM <table_name> WHERE <condition> LIMIT 10" | \
  jenkins-tool db-query select -d data-warehouse
```

### 6. 验证写入结果（双重断言）

先写后查：
```bash
# 写
jenkins-tool db-query exec -d data-warehouse --confirm -s \
  "INSERT INTO <table_name> (<column_name>) VALUES ('test')"

# 查
echo "SELECT * FROM <table_name> WHERE <column_name>='test' LIMIT 5" | \
  jenkins-tool db-query select -d data-warehouse
```

## 常见问题速查

| 现象 | 原因 | 处理 |
|------|------|------|
| `--database is required` | 未指定 `-d` | 补齐连接名，`-d data-warehouse` |
| `connection 'xxx' not found` | 配置文件中无此连接 | 检查 `~/.jenkins_tool_credentials.json` |
| `failed to connect` | 数据库不可达 | 先 `ping` 测试，确认 `test-mysql-rds.poi-t.cn:991` 可达 |
| `--confirm is required` | exec 缺 `--confirm` | 加上 `--confirm` 或 `-y` |
| `only INSERT/UPDATE allowed` | 传入了 DELETE/DROP/SELECT | exec 只接受 INSERT/UPDATE |
| `UPDATE must include WHERE` | UPDATE 无 WHERE 条件 | 添加 WHERE 子句 |
| `query timed out` | 查询超时（默认 30s） | 加 `--timeout 60s` 或优化 SQL |
| `result exceeds 1000 rows` | 结果集超限 | 加 WHERE 缩范围或 `--limit` 降级 |

## 执行步骤

收到查询请求时：

1. **确认目标** — 查什么表、什么字段、什么条件
2. **连接 `data-warehouse`** — 所有查询统一用 `-d data-warehouse`
3. **先看结构** — 不确定字段时先跑 `ddl` 看表结构
4. **执行查询** — 拼 SQL 时带上必要 WHERE 条件和 `LIMIT`
5. **解读结果** — JSON 结构化输出，翻译字段含义，给出业务解读

## 边界与默认行为

- **默认只读**：优先 SELECT，写操作需用户显式确认
- **默认带 LIMIT**：不确定数据量时不传 `--limit`，依赖默认 1000 上限
- **默认先看结构**：不确定字段或索引时先用 `ddl` 查看表结构
- **不修改数据**：写操作需用户显式确认；`DELETE/DROP/ALTER/TRUNCATE` 被工具层拒绝
- **金额字段是 DECIMAL(19,7)**：不要用浮点运算，直接用数据库值
- **敏感字段不直接输出**：密码、token、密钥等敏感字段在输出中需提醒用户脱敏
