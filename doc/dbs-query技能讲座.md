# DBS / Archery 远程查询技能讲座

> **主题**：用 `.codex/skills/dbs-query` 安全获取物料数据，并把查询结果整理成可审阅的 SQL
>
> **示例项目**：美味鲜物料库（MySQL）
>
> **配套文件**：[`material_measure_unit_box.json`](../center/美味鲜/material_measure_unit_box.json)、[`material_measure_unit_kilogram.json`](../center/美味鲜/material_measure_unit_kilogram.json)、[`material_kilogram_unit_to_ton.sql`](../center/美味鲜/material_kilogram_unit_to_ton.sql)

## 1. 讲座目标

完成本讲座后，可以：

1. 解释 DBS、Archery、实例、数据库和 Target 的关系。
2. 使用 `dbs-query` 发现当前账号可读的资源，并固定查询目标。
3. 先看表结构，再写带字段、条件、排序和行数上限的只读 SQL。
4. 将返回数据保存为可追溯的 JSON 快照，并从快照生成批量 SQL。
5. 识别认证失效、目标不唯一、字段不确定和权限不足等常见问题。

## 2. 先看示例数据

仓库中的箱装快照有 **2,481** 行，字段为 `material_id`、`material_code`、`material_name`、`measure_unit`、`unit`；`measure_unit` 和 `unit` 均为 `箱`、`箱(6)`、`箱(12)` 等箱装单位。

千克快照有 **1,767** 行、**1,767** 个不同的 `material_id`，每行的 `measure_unit` 都是 `千克`。目标 SQL 只使用这些 ID，并把两个单位字段统一写为 `吨`。

示例首行（来自箱装快照）：

```json
{
  "material_id": 100001,
  "material_code": "B010300032",
  "material_name": "5L*2罐厨邦味极鲜酱油（酿造酱油）（日韩版）",
  "measure_unit": "箱(2)",
  "unit": "箱(2)"
}
```

> 快照是输入证据，不等于写入授权。先确认目标、条件和差异数量，再决定是否执行更新。

## 3. `dbs-query` 的工作方式

`dbs-query` 在本地运行 CLI，通过 Archery 访问已授权的远程数据库。Target 把站点、实例、数据库和（如适用）schema 固定成一个别名；每次查询都显式传 `--target`，避免把 SQL 发到错误环境。

```text
本地 CLI  →  Archery/DBS  →  已授权实例  →  数据库/表
             └─ Target 固定站点、实例、数据库
```

安全边界：

- 只接受 `SELECT` 和只读 CTE；拒绝 `UPDATE`、`DELETE`、DDL、多语句和锁行查询。
- 不直连数据库，不手写带 Cookie、Session、CSRF Token 或密码的请求。
- 密码只放在用户目录的 `~/.dbs_config.json`，不放进仓库。
- DBS 查询用于取证和核对；本讲座的写入 SQL 需经过审批并使用独立写入渠道。

## 4. 标准操作流程

### 4.1 检查登录态

在仓库根目录执行：

```bash
DBS=.codex/skills/dbs-query/dbs.py
$DBS --compact auth status --site poit
```

如果返回 `AUTH_REQUIRED`，在自己的终端交互登录：

```bash
$DBS auth login --site poit
```

不要把密码作为命令参数，也不要循环重试失效会话。

### 4.2 搜索并确认 Target

```bash
$DBS --compact target list --search 美味鲜
$DBS --compact target show meiweixian-prod-material
```

本例使用的 Target 是 `meiweixian-prod-material`，对应“美味鲜生产MySQL”上的 `poit-material` 数据库。生产目标必须由操作者确认；名称相近时先列出候选，不要猜测。

### 4.3 先看表结构，再查数据

```bash
$DBS --compact desc \
  --target meiweixian-prod-material \
  material
```

环境取证可以使用同一个 Target：

```bash
$DBS --compact query --target meiweixian-prod-material \
  --table material \
  --sql "SELECT VERSION() AS db_version" --limit 1

$DBS --compact query --target meiweixian-prod-material \
  --table material \
  --sql "SELECT @@sql_mode AS sql_mode" --limit 1
```

### 4.4 查询箱装物料

只取需要的列，带稳定排序和行数上限：

```bash
$DBS --compact query \
  --target meiweixian-prod-material \
  --table material \
  --columns material_id,material_code,material_name,measure_unit,unit \
  --where "rec_status = 1 AND measure_unit LIKE '箱%'" \
  --limit 20
```

箱装快照超过 1,000 行时，按 `material_id` 做 keyset 分页。每次最多 1,000 行，把上一页最后一个 ID 代入 `<last_id>`：

```bash
$DBS --compact query \
  --target meiweixian-prod-material \
  --table material \
  --columns material_id,material_code,material_name,measure_unit,unit \
  --where "rec_status = 1 AND measure_unit LIKE '箱%' AND material_id > <last_id>" \
  --limit 1000
```

这样可以避免无序分页导致重复或遗漏；导出 JSON 时保留查询条件、排序规则、时间和 Target 名称作为元数据。

## 5. 从快照生成单位转换 SQL

### 5.1 生成规则

本例的输入是 `material_measure_unit_kilogram.json`，规则是：

- 取每行 `material_id`，去重后升序排列。
- 只处理 `rec_status = 1` 且当前 `measure_unit = '千克'` 的记录。
- 同时写入 `measure_unit = '吨'` 和 `unit = '吨'`。
- 使用 `<=>` 进行 null-safe 比较，保证重复执行不会产生无意义更新。
- SQL 只包含单条 `UPDATE`，不包含凭据、Cookie 或远程执行逻辑。

一个最小的本地生成脚本如下：

```python
import json
from pathlib import Path

rows = json.loads(Path("center/美味鲜/material_measure_unit_kilogram.json").read_text())
ids = sorted({row["material_id"] for row in rows})
assert all(row["measure_unit"] == "千克" for row in rows)
print(f"-- source rows: {len(rows)}, distinct ids: {len(ids)}")
print("UPDATE `material` SET `measure_unit` = '吨', `unit` = '吨' ...")
```

完整产物见 [`center/美味鲜/material_kilogram_unit_to_ton.sql`](../center/美味鲜/material_kilogram_unit_to_ton.sql)。文件包含 1,767 个去重 ID，并加上了 `measure_unit = '千克'` 的来源条件。

### 5.2 执行前后核对（写入渠道）

`dbs-query` 本身不能执行下面的更新。执行前可在有写权限的、已审批环境中核对数量：

```sql
SELECT COUNT(*) AS candidate_count
FROM `material`
WHERE `rec_status` = 1
  AND `measure_unit` = '千克'
  AND `material_id` IN (/* 使用目标 SQL 中的 ID */);
```

执行目标 SQL 后复查：

```sql
SELECT COUNT(*) AS remaining_count
FROM `material`
WHERE `rec_status` = 1
  AND `measure_unit` = '千克'
  AND `material_id` IN (/* 同一批 ID */);
```

预期 `remaining_count = 0`；若数量不符，停止后续操作并保留查询结果、SQL 哈希和执行时间供审计。

## 6. 常见错误与处理

| 错误 | 含义 | 处理 |
| --- | --- | --- |
| `AUTH_REQUIRED` | Archery 会话失效或返回登录页 | 交互执行 `auth login`，不要把密码写进命令或日志 |
| `TARGET_NOT_FOUND` | Target 名称错误或未配置 | `target list` 搜索；必要时由操作者确认后创建 |
| `INSTANCE_NOT_FOUND` / `DATABASE_NOT_FOUND` | 当前缓存中找不到资源 | 只刷新一次资源列表，再确认实例和数据库 |
| `QUERY_REJECTED` | SQL 含写操作、多语句或副作用函数 | 改成单条只读 `SELECT` |
| 字段不确定 | 表结构与假设不一致 | 先执行 `desc`，再收敛列和条件 |

本次讲座生成时，本地配置能够列出 `meiweixian-prod-material`，但实际 `desc/query` 返回 `AUTH_REQUIRED`。因此示例快照使用仓库中已保存的 JSON；重新登录后可以按第 4 节复现查询。

## 7. 讲座建议流程（45 分钟）

| 时间 | 内容 | 练习产物 |
| --- | --- | --- |
| 0–5 分钟 | DBS、Archery、Target 与只读边界 | 说出 Target 固定了哪些信息 |
| 5–15 分钟 | 登录态、资源发现、`desc` | 找到美味鲜物料库和 `material` 表 |
| 15–25 分钟 | 列选择、WHERE、排序、分页 | 获取箱装物料样本 |
| 25–35 分钟 | JSON 快照与 ID 集合 | 统计 2,481 / 1,767 行 |
| 35–42 分钟 | 生成、预检和复查 SQL | 审阅 `material_kilogram_unit_to_ton.sql` |
| 42–45 分钟 | 错误处理与安全复盘 | 说明 `AUTH_REQUIRED` 的正确处理 |

## 8. 复盘清单

- [ ] 目标是唯一且经过操作者确认。
- [ ] 已检查认证状态，未把秘密写入仓库。
- [ ] 已执行 `desc`，字段名和类型有依据。
- [ ] 查询只选必要列，带 WHERE、稳定 ORDER BY 和 LIMIT。
- [ ] JSON 快照记录来源、时间、Target 和查询口径。
- [ ] 写入 SQL 与快照 ID 集合一致，具备来源条件和幂等保护。
- [ ] 写入前后都有数量核对，DBS 只承担只读查询。
