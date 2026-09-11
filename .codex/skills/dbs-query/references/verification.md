# 只读验证与证据摘要

阶段 A 只在本地调用 `dbs-query`，Cloud 不接收 DBS Session，也不直连站点业务库。每次验证都先确认 Target，再确认 `can_read` 资源：

```bash
.codex/skills/dbs-query/dbs.py auth status --site <user-confirmed-site>
.codex/skills/dbs-query/dbs.py target list --search <keyword>
.codex/skills/dbs-query/dbs.py instance list --site <site> --db-type mysql
.codex/skills/dbs-query/dbs.py query --target <confirmed-target> --sql "SELECT VERSION()" --limit 1
.codex/skills/dbs-query/dbs.py query --target <confirmed-target> --sql "SELECT @@sql_mode" --limit 1
.codex/skills/dbs-query/dbs.py desc --target <confirmed-target> <table>
```

用户确认字段、`WHERE`、稳定 `ORDER BY` 和 `LIMIT` 后，原 SQL 与改写 SQL 必须在同一 Target 使用完全相同的条件和 limit，各执行一次。建议把返回结果在本地传给 `scripts.verification.compare_result_sets`，输出只含列数、行数、SQL 哈希和首个差异位置，不保存行值。

## Evidence schema v1

机器校验入口是 `scripts.verification.validate_evidence`；样例见 `fixtures/verification_evidence.json`。摘要必须包含：

- `dbsTargetAlias`、`dbVersionSummary`、`sqlModeSummary`、`capturedAt`；
- 每个只读检查的 `sqlSha256`（前 16 位）、`whereSummary`、`orderBySummary`、`limit`、`rowCount`；
- 改写对照的两侧哈希、相同条件/排序/limit、两侧行数、`firstDifference`（仅索引和原因）及 `PASS`/`FAIL`/`NOT_VERIFIED` 结论。

证据禁止行值、完整 SQL、凭据、Cookie、Session、密码、Token、profile 和响应原文。非法 JSON 对照不能凭静态推断等价：使用 `fixtures/illegal_json_comparison.json` 的 `NOT_VERIFIED` 语义，必须在用户确认 Target 上分别实测 `JSON_VALUE ... RETURNING` 与改写表达式，并仅记录 NULL/报错状态摘要。

写 SQL 不得拆分绕过只读限制；真实写入验证使用计算任务调试回滚或用户明确授权的开发环境 `db-query`，不是本 Skill 的 DBS 查询命令。
