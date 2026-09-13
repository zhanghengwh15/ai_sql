---
name: dbs-query
description: 通过远程 DBS/Archery 发现当前用户可读的数据库实例和数据库，保存查询目标，并执行只读 SQL 或查看表结构。用户提到 DBS、Archery、远程数据库、数据库实例、远程查数据或远程表结构时使用；本地数据库、jenkins-tool 和 go-mini-shop 查询使用 db-query，不使用本技能。
---

# DBS / Archery 远程数据库查询

使用本 Skill 自带的 CLI，通过 Archery 已授权资源访问远程数据库。不要直连数据库，也不要手写包含浏览器 Cookie 的 curl。

## 命令入口

在仓库根目录执行：

```bash
.codex/skills/dbs-query/dbs.py <command>
```

需要完整参数时读取 [references/cli.md](references/cli.md)。

阶段 A 验证命令序列、证据 schema 和改写对照规则见
[references/verification.md](references/verification.md)。Cloud 只接收脱敏摘要，不直连 DBS。

## 执行流程

1. 读取 `config/dbs-config.json` 中的站点、默认用户名和 Target。用户提供客户、系统或数据库名称时，先运行 `target list --search <关键词>` 匹配名称、说明和别名。
2. 运行 `auth status --site <site>` 检查本地登录态。查询类命令会在本地 Session 缺失时自动从用户目录 `~/.dbs_config.json`（Windows 为 `%USERPROFILE%\.dbs_config.json`）读取密码并登录；没有该文件或密码时，再让用户在自己的终端交互执行 `auth login --site <site>`。
3. 已配置 Target 必须唯一对应站点、实例和数据库；上下文不足时列出候选并让用户选择，禁止猜测生产或测试环境。
4. 没有合适 Target 时，依次运行 `instance list`、`database list`，确认用户选择后运行 `target add`。实例与数据库首次请求后会缓存，不要为了预热而遍历所有实例。
5. 字段或表结构不确定时先运行 `desc`，再生成查询。
6. 查询必须显式传 `--target`。优先选择必要字段和收敛的 WHERE 条件，默认 `--limit 100`；只有用户确实需要时才提高，上限 1000。
7. 向用户说明实际 Target、关键条件、行数与结论。除非用户明确需要，不要倾倒大结果集或输出 `--raw` 响应。

环境取证固定执行 `SELECT VERSION()` 和 `SELECT @@sql_mode`（均 `--limit 1`）；路径 A 改写对照两侧必须复用同一 Target、WHERE、ORDER BY 和 LIMIT。结果进入证据前只保留 SQL 哈希、行数、列数和首个差异索引。

## 安全边界

- 仅允许 `SELECT` 和只读 CTE。CLI 会拒绝写操作、DDL、多语句、锁行查询和已知副作用函数。
- 本技能不提供任何远程写入命令。用户要求修改数据时，说明该 Skill 仅支持只读查询。
- 只使用 `can_read` 接口返回的实例和实例资源接口返回的数据库创建 Target。
- MySQL 和 PostgreSQL 可建立 SQL Target。Redis 实例只在发现结果中展示，当前不执行 Redis 查询。
- Cookie、Session ID、CSRF Token、密码不得进入项目代码、共享配置、文档、日志或最终回复。AI 不使用隐藏的 `-p` 测试参数。
- `config/dbs-config.json` 只能保存 URL、用户名和 Target；密码仅允许保存到用户目录的 `~/.dbs_config.json`（Windows 为 `%USERPROFILE%\.dbs_config.json`），该文件必须设置为仅当前用户可读（Unix `0600`）。
- `AUTH_REQUIRED` 时只提示重新登录，不循环重试。资源权限变化时最多使用一次 `--refresh` 重新发现。

## 资源与配置

- 站点、用户名、私有部署 URL 和常用 Target 统一维护在 [config/dbs-config.json](config/dbs-config.json)。密码维护在用户目录的 `.dbs_config.json`，不加入项目。
- 维护或排查 Archery 请求时读取 [references/archery-api.md](references/archery-api.md)。
- 检查本地状态、权限或迁移配置时读取 [references/configuration.md](references/configuration.md)。
- `db-query` 是本地数据库 Skill；不要用它代替本 Skill，也不要把本 Skill 的 Session 写入本地数据库凭据文件。
