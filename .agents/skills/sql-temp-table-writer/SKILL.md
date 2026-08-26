---
name: sql-temp-table-writer
description: 为 MySQL 8 离线/定时跑批编写安全 SQL。对短小的单表批量更新，直接输出单条 UPDATE，不创建临时表；对"原始数据 → 处理 → 写入目标表 → 回写状态"这类复杂多表、聚合或需要成功子集校验的场景，使用 TEMPORARY TABLE 分阶段处理。用户要求使用临时表中转、或防止"中间过程未处理却把状态置为已完成"时，使用此技能。
---

# SQL 临时表批处理编写规范

## 适用场景

### 0. 先判定是否需要临时表

满足以下条件时，视为**简单单表批量更新**：只更新一张表；无聚合、JSON 拼装、多步派生或跨表写入；无需通过另一张表或中间结果确认「成功子集」；所有业务条件均可在同一条 `WHERE` 中准确表达。**此时不要创建临时表 A 或 Staging，也不要输出 DROP 和分步验证 SQL；直接输出一条 UPDATE。**

直接 UPDATE 必须满足：

- 【强制】`WHERE` 包含待处理/幂等条件，且本次更新会使该行不再满足该条件，例如 `cal_status = 1` 更新为 `cal_status = 2`；不要只更新 `modify_time` 后反复命中同一批数据。
- 时间窗口、排序和处理范围按业务需求添加，不作默认限制。

```sql
UPDATE `yt_xxx_original_data`
SET `cal_status` = 2,
    `modify_time` = NOW(),
    `modify_by` = '{{operator}}'
WHERE `cal_status` = 1
  AND `modify_time` >= NOW() - INTERVAL 24 HOUR;
```

出现任一情形时，使用下方临时表流程：需要跨表 `JOIN` 才能确认更新成功、需要写入另一张表后再回写状态、存在聚合 / `JSON_ARRAYAGG` / 去重 / 多步派生，或需要固定本批候选范围以便后续多步复用。

把"一次性、长 SQL、写入 + 回写状态"的批处理脚本，重写为：

1. 临时表 A：锁定本次要处理的原始数据 ID 范围（可按业务**扩列**：`id` + 关联键 + 写入载荷，减少二次临时表）
2. 数据预处理：在原始表上做必要的字段补全
3. 临时表 B (Staging)：**可选**。存在聚合、`JSON_ARRAYAGG`、多步派生、或 INSERT 目标结构复杂时，用 Staging 承载「通过校验后的成功子集」
4. 写入最终表：从 Staging `INSERT` / `UPDATE`，或见下「免 Staging」时对业务表直接 `UPDATE ... JOIN`
5. 回写状态：**只回写与「成功子集」约束一致的记录**（`JOIN Staging` **或** `INNER JOIN` 目标业务表且条件等价），未通过校验的不回写
6. 收尾：删除全部临时表

## 编写硬性规范（必须遵守）

### 1. 临时表头尾都要 DROP
- 【强制】脚本**开头**必须 `DROP TEMPORARY TABLE IF EXISTS` 所有要用到的临时表，防止上次未清理残留
- 【强制】脚本**结尾**必须再次 `DROP TEMPORARY TABLE IF EXISTS` 全部临时表，释放连接资源
- 【强制】临时表命名以 `_tmp` 结尾，前缀沿用主表前缀（含项目前缀），便于排查

### 2. 临时表范围必须有业务条件
使用临时表流程时，每个用于确定批次范围的 `CREATE TEMPORARY TABLE ... AS SELECT` 都必须包含准确的业务过滤条件。时间窗口、排序和处理范围按业务需求添加，不作默认限制。

### 3. 状态回写的逻辑安全
- 【强制】**成功子集与回写范围必须一致**：`UPDATE ... SET 完成态` 时，生效行必须等价于「真正处理成功」的行；约束方式二选一（或组合）：
  - **Staging 表**：`JOIN staging_tmp`，且 Staging 内仅为通过校验的数据；
  - **免 Staging、直接 JOIN 原业务表**：`UPDATE 同步表 d JOIN 范围_tmp s ... INNER JOIN 目标业务表 t ON <关联键>`，使**只有关联命中**的同步行 / 业务行被更新；效果与「先算 Staging 再 JOIN」相同。
- 【强制】**禁止**仅依据「本次锁定范围」（仅有 `id` 的范围临时表、且 **UPDATE 中未** `INNER JOIN` 业务成功条件 / Staging）就把状态置为已完成 —— 未命中业务表或未通过校验的记录不得标记成功。
- 【强制】回写时同步更新 `modify_time`、`modify_by`（参考项目 MySQL 规范）
- 【推荐】对未进入成功子集（未进 Staging 或未命中业务 `JOIN`）的「被锁定」记录，可单独 `UPDATE` 为「待重试 / 异常」状态（如 `cal_status = 3`），便于追踪

### 3.1 免 Staging：扩列范围表 + 原表 INNER JOIN（经验沉淀）

当本批**无聚合、无 JSON 拼装、无多步中间结果**，仅做「同步表 ↔ 业务表」键上更新时，**不必再建第二张 Staging 临时表**：

1. **范围临时表扩列**：使用 `CREATE TEMPORARY TABLE ..._scope_tmp AS SELECT id, 关联键列, 写入所需载荷列 ... FROM 源表 WHERE ...`，一次锁定并带上 `UPDATE` 要用的字段，避免重复扫描源表条件。
2. **业务表 `UPDATE`**：`UPDATE 业务表 t JOIN ..._scope_tmp s ON t.键 = s.键 JOIN 源表 d ON d.id = s.id SET ...`，并用 `d` 上仍为「待处理」的状态条件防止并发重复改。
3. **同步状态回写**：`UPDATE 源表 d JOIN ..._scope_tmp s ... INNER JOIN 业务表 t ON ... SET 完成态`，与第 2 步 **同一套命中条件**，保证「能置完成态」当且仅当「业务侧已命中」。

**仍须遵守**：范围表的 `CREATE ... AS SELECT` 带准确业务条件；头尾 `DROP` 所有临时表。

**仍建 Staging 的典型情况**：按单号 `GROUP BY` 聚合明细、`JSON_ARRAYAGG`、去重子查询结果集较大、或 INSERT 列来自多表拼接 —— 继续用两段式（范围 + Staging）更清晰、易验证。

### 4. MySQL 8 函数使用
本技能默认运行环境为 **MySQL 8**，可使用：

- `ANY_VALUE(col)` ：兼容 `ONLY_FULL_GROUP_BY`，用于 GROUP BY 中非聚合列
- `JSON_OBJECT(...)` / `JSON_ARRAYAGG(...)` ：聚合明细行为 JSON
- `JSON_OBJECTAGG(k, v)` ：键值对聚合
- `WITH cte AS (...)` 公共表表达式（CTE）
- 不要使用 `ROW_NUMBER() OVER (PARTITION BY ...)` 或其他窗口函数，系统对此存在已知问题；需要排序、去重或分组取值时，改用临时表、聚合或关联查询。

### 5. 验证 SQL
仅在用户明确要求时附带验证 `SELECT`，作为独立 SQL 输出，不使用块注释包裹。

### 6. 注释
每个步骤最多保留一条单行 `--` 注释，不添加行内注释、分隔线或大段说明。

## 输出模板（复杂临时表流程）

先按 §0 分流：简单单表批量更新只输出 §0 的单条 `UPDATE` 模式；下面模板只用于需要临时表的复杂场景。把表名、字段名、过滤条件替换为具体业务即可。

```sql
-- 0. 清理可能残留的临时表
DROP TEMPORARY TABLE IF EXISTS yt_xxx_original_data_tmp;
DROP TEMPORARY TABLE IF EXISTS yt_xxx_staging_tmp;

-- 1. 临时表 A：锁定本次要处理的原始数据范围
CREATE TEMPORARY TABLE yt_xxx_original_data_tmp AS (
  SELECT id
  FROM yt_xxx_original_data
  WHERE cal_status = 1
    AND batch_no IS NOT NULL
);

-- 2. 数据预处理：补全字段（仅对本次范围操作）
UPDATE yt_xxx_original_data
SET entry_store_location_code = CASE
      WHEN receiving_warehouse_store_code = '865' THEN '865'
      WHEN receiving_warehouse_store_code = '866' THEN '866'
      WHEN receiving_warehouse_store_code = '864' THEN '864'
      WHEN receiving_warehouse_store_code = '863' THEN '863'
    END,
    modify_time = NOW()
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp);

-- 3. 临时表 B (Staging)：只放真正通过所有校验的数据
CREATE TEMPORARY TABLE yt_xxx_staging_tmp AS (
  SELECT
    docket_code,
    ANY_VALUE(record_no)                       AS record_no,
    ANY_VALUE(receiving_warehouse_store_code)  AS store_code,
    ANY_VALUE(stock_transfer_num)              AS stock_transfer_num,
    ANY_VALUE(entry_fid)                       AS entry_fid,
    JSON_ARRAYAGG(
      JSON_OBJECT(
        'entryTime',              entry_time,
        'materialCode',           material_code,
        'batchNo',                batch_no,
        'quantity',               quantity,
        'entryStoreLocationCode', entry_store_location_code
      )
    ) AS formatted_json
  FROM yt_xxx_original_data
  WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
    AND entry_store_location_code IS NOT NULL
    AND stock_transfer_num NOT IN (
      SELECT number
      FROM yt_beijian_json_hbcc
      WHERE modify_time >= NOW() - INTERVAL 100 HOUR
    )
  GROUP BY docket_code
);

-- 4. 写入最终表：从 Staging 表写入
INSERT INTO yt_xxx_finsh_data (
  docket_code,
  record_no,
  receiving_warehouse_store_code,
  stock_transfer_num,
  entry_fid,
  docket_detail_list
)
SELECT
  docket_code,
  record_no,
  store_code,
  stock_transfer_num,
  entry_fid,
  formatted_json
FROM yt_xxx_staging_tmp
ON DUPLICATE KEY UPDATE
  docket_detail_list = VALUES(docket_detail_list),
  modify_time        = NOW();

-- 5. 状态回写：仅更新成功子集
UPDATE yt_xxx_original_data m
JOIN yt_xxx_staging_tmp staging
  ON m.docket_code = staging.docket_code
SET m.cal_status  = 2,
    m.modify_time = NOW()
WHERE m.entry_store_location_code IS NOT NULL
  AND m.id IN (SELECT id FROM yt_xxx_original_data_tmp);

-- 6. 收尾：清理临时表
DROP TEMPORARY TABLE IF EXISTS yt_xxx_original_data_tmp;
DROP TEMPORARY TABLE IF EXISTS yt_xxx_staging_tmp;
```

## 编写流程（生成 SQL 时按顺序执行）

1. 先判断是否满足 §0 的简单单表 UPDATE 条件；满足则仅输出带待处理条件的单条 UPDATE。
2. 不满足时，确认源表、目标表、状态字段、关联唯一键和需要聚合成 JSON 的字段。
3. 套用复杂临时表模板，把占位符替换为业务字段。
4. 复杂临时表流程检查清单（在交付前自检）：
   - [ ] 头部 DROP TEMPORARY TABLE 是否完整覆盖所有临时表？
   - [ ] 尾部 DROP TEMPORARY TABLE 是否完整覆盖所有临时表？
   - [ ] 每个 CREATE TEMPORARY TABLE 是否包含准确的业务过滤条件？
   - [ ] 状态回写 / 完成态 UPDATE 是否与「成功子集」一致（`JOIN Staging`，或 **`INNER JOIN` 业务表且与业务 UPDATE 条件等价**，而不是仅用范围表 `id IN (...)` 置成功）？
   - [ ] 是否只在用户明确要求时提供验证 `SELECT`？
   - [ ] 是否避免了窗口函数，且每个步骤最多有一条单行注释？
   - [ ] 多租户场景：是否在过滤条件里带了 `org_id`？

## 与项目其他规范的关系

- 表 / 字段 / 索引命名遵循 `.claude/rules/mysql-database-standards.md`
- SQL 整洁度 / 注释要求遵循 `.claude/rules/sql-logic-principles.md`
- 本技能只规定"批处理 SQL 的写法"，不覆盖建表、索引设计

## 维护说明

- 输出 SQL 的注释只保留步骤级单行 `--` 注释；不要恢复验证 SQL 块、分隔线、行内注释或大段模板说明，以保持脚本简洁。
- 不默认添加 `LIMIT`、默认批次大小或由此配套的排序限制；处理范围应由具体业务条件或用户明确要求决定。
- 不要恢复 `ROW_NUMBER()` 或其他窗口函数；系统存在已知兼容问题，排序、去重和分组取值应继续采用临时表、聚合或关联查询。
- 这些约束优先于旧模板或引用资料中的相反示例；后续修改本技能时应保持一致。
