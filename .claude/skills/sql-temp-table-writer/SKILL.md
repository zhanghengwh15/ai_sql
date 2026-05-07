---
name: sql-temp-table-writer
description: 基于临时表 (TEMPORARY TABLE) 模式编写 MySQL 8 批处理 SQL，用于"原始数据 → 处理 → 写入目标表 → 回写状态"的离线/定时跑批场景。当用户需要把单条复杂的多表写入/状态回写 SQL 改写成"先锁定数据范围、再校验聚合、最后回写状态"的安全分阶段 SQL，或要求使用临时表中转、需要附带分步 SELECT 验证语句、需要防止"中间过程未处理却把状态置为已完成"的逻辑漏洞时，使用此技能。
---

# SQL 临时表批处理编写规范

## 适用场景

把"一次性、长 SQL、写入 + 回写状态"的批处理脚本，重写为：

1. 临时表 A：锁定本次要处理的原始数据 ID 范围
2. 数据预处理：在原始表上做必要的字段补全
3. 临时表 B (Staging)：存放真正通过所有校验的数据（聚合 / JSON 拼装等）
4. 写入最终表：从 Staging 表 INSERT 到目标表
5. 回写状态：**只回写真正进入 Staging 的记录**，未通过校验的不回写
6. 收尾：删除全部临时表

## 编写硬性规范（必须遵守）

### 1. 临时表头尾都要 DROP
- 【强制】脚本**开头**必须 `DROP TEMPORARY TABLE IF EXISTS` 所有要用到的临时表，防止上次未清理残留
- 【强制】脚本**结尾**必须再次 `DROP TEMPORARY TABLE IF EXISTS` 全部临时表，释放连接资源
- 【强制】临时表命名以 `_tmp` 结尾，前缀沿用主表前缀（含项目前缀），便于排查

### 2. CREATE TEMPORARY TABLE 必须加保护条件
每个 `CREATE TEMPORARY TABLE ... AS SELECT` 都必须包含以下两类保护条件，避免误锁全表 / 处理量爆炸：

- 【强制】**时间窗口**：必须包含 `modify_time >= NOW() - INTERVAL N HOUR`（或等价的时间过滤），优先用 `modify_time` 这种带索引、带更新语义的字段
- 【强制】**LIMIT 兜底**：必须显式 `LIMIT N`（建议 `LIMIT 5000` 或按业务批次大小），防止单次跑批撑爆内存 / binlog
- 【强制】`ORDER BY id` 配合 LIMIT，保证可重入、可断点续跑

### 3. 状态回写的逻辑安全
- 【强制】**只回写真正进入 Staging 表的记录**：`UPDATE ... SET cal_status = 2` 必须 `JOIN staging_tmp` 来约束范围
- 【强制】**禁止**仅依据"本次锁定范围"（临时表 A）就把状态置为已完成 —— 因为未通过校验的记录不应被标记成功
- 【强制】回写时同步更新 `modify_time`、`modify_by`（参考项目 MySQL 规范）
- 【推荐】对未进入 Staging 的"被遗漏"记录，可单独 UPDATE 为"待重试 / 异常"状态（如 `cal_status = 3`），便于追踪

### 4. MySQL 8 函数使用
本技能默认运行环境为 **MySQL 8**，可放心使用：

- `ANY_VALUE(col)` ：兼容 `ONLY_FULL_GROUP_BY`，用于 GROUP BY 中非聚合列
- `JSON_OBJECT(...)` / `JSON_ARRAYAGG(...)` ：聚合明细行为 JSON
- `JSON_OBJECTAGG(k, v)` ：键值对聚合
- `WITH cte AS (...)` 公共表表达式（CTE）
- `ROW_NUMBER() OVER (PARTITION BY ...)` 等窗口函数

### 5. 分步 SELECT 验证语句（必须附带）
每个临时表创建之后、每个 INSERT/UPDATE 之前，必须在注释块中给出对应的"调试用 SELECT"，方便上线前手工对数。详见 [references/validation-template.md](references/validation-template.md)。

## 输出模板（直接套用）

下面是规范化模板。把表名、字段名、过滤条件替换为具体业务即可。

```sql
-- =====================================================================
-- 业务名称：{{业务说明，例如：EAS 调拨入库数据加工与回写}}
-- 主表：    {{yt_xxx_original_data}}
-- 目标表：  {{yt_xxx_finsh_data}}
-- 触发方式：{{定时任务 / 手动 / 事件触发}}
-- 作者：    {{name}}    日期：{{YYYY-MM-DD}}
-- 说明：    采用临时表两段式（范围表 + Staging 表）模式，
--          只回写真正通过校验的记录，避免脏状态。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 收尾保险：先清理可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS yt_xxx_original_data_tmp;
DROP TEMPORARY TABLE IF EXISTS yt_xxx_staging_tmp;

-- ---------------------------------------------------------------------
-- 1. 临时表 A：锁定本次要处理的原始数据范围
--    - 必须有 modify_time 时间窗口
--    - 必须有 LIMIT 兜底
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE yt_xxx_original_data_tmp AS (
  SELECT id
  FROM yt_xxx_original_data
  WHERE cal_status = 1                                           -- 待处理
    AND batch_no IS NOT NULL                                     -- 业务必要条件
    AND modify_time >= NOW() - INTERVAL 24 HOUR                  -- 【强制】时间窗口
  ORDER BY id
  LIMIT 5000                                                     -- 【强制】LIMIT 兜底
);

-- 【验证 SQL-1】确认本次锁定的范围（上线前手工执行）
-- SELECT COUNT(*) AS lock_cnt FROM yt_xxx_original_data_tmp;
-- SELECT * FROM yt_xxx_original_data
--  WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp) LIMIT 20;

-- ---------------------------------------------------------------------
-- 2. 数据预处理：补全字段（仅对本次范围操作）
-- ---------------------------------------------------------------------
UPDATE yt_xxx_original_data
SET entry_store_location_code = CASE
      WHEN receiving_warehouse_store_code = '865' THEN '865'
      WHEN receiving_warehouse_store_code = '866' THEN '866'
      WHEN receiving_warehouse_store_code = '864' THEN '864'
      WHEN receiving_warehouse_store_code = '863' THEN '863'
    END,
    modify_time = NOW()
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp);

-- 【验证 SQL-2】确认补全结果，重点关注 entry_store_location_code 是否仍为 NULL
-- SELECT entry_store_location_code, COUNT(*) AS cnt
--   FROM yt_xxx_original_data
--  WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
--  GROUP BY entry_store_location_code;

-- ---------------------------------------------------------------------
-- 3. 临时表 B (Staging)：只放真正通过所有校验的数据
--    - 校验条件统一在这一步表达
--    - 同样要带 LIMIT 兜底（聚合后行数会变小，按业务设定）
-- ---------------------------------------------------------------------
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
    AND entry_store_location_code IS NOT NULL                    -- 必须补全成功
    AND stock_transfer_num NOT IN (                              -- 业务去重校验
      SELECT number
      FROM yt_beijian_json_hbcc
      WHERE modify_time >= NOW() - INTERVAL 100 HOUR
    )
  GROUP BY docket_code
  LIMIT 5000                                                     -- 【强制】LIMIT 兜底
);

-- 【验证 SQL-3】对比锁定范围与最终通过校验的记录数，差额即"被过滤掉的"
-- SELECT
--   (SELECT COUNT(*) FROM yt_xxx_original_data_tmp)  AS locked_cnt,
--   (SELECT COUNT(*) FROM yt_xxx_staging_tmp)        AS passed_cnt;
-- SELECT * FROM yt_xxx_staging_tmp LIMIT 5;

-- ---------------------------------------------------------------------
-- 4. 写入最终表：从 Staging 表写入
-- ---------------------------------------------------------------------
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

-- 【验证 SQL-4】抽样核对最终表是否正确写入
-- SELECT f.* FROM yt_xxx_finsh_data f
--   JOIN yt_xxx_staging_tmp s ON f.docket_code = s.docket_code LIMIT 5;

-- ---------------------------------------------------------------------
-- 5. 状态回写：【只回写真正进入 Staging 的记录】
--    - 严禁仅根据临时表 A（锁定范围）就把状态置为已完成
--    - 未通过校验的记录保持 cal_status = 1（或单独标记重试）
-- ---------------------------------------------------------------------
UPDATE yt_xxx_original_data m
JOIN yt_xxx_staging_tmp staging
  ON m.docket_code = staging.docket_code
SET m.cal_status  = 2,
    m.modify_time = NOW()
WHERE m.entry_store_location_code IS NOT NULL
  AND m.id IN (SELECT id FROM yt_xxx_original_data_tmp);

-- 【可选】把"被锁定但未通过校验"的记录单独标记为待重试（cal_status = 3）
-- UPDATE yt_xxx_original_data
--    SET cal_status  = 3,
--        modify_time = NOW()
--  WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
--    AND cal_status = 1;   -- 仍然是"待处理"说明上一步没回写为 2

-- 【验证 SQL-5】回写完成后的状态分布
-- SELECT cal_status, COUNT(*) AS cnt
--   FROM yt_xxx_original_data
--  WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
--  GROUP BY cal_status;

-- ---------------------------------------------------------------------
-- 6. 收尾：清理临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS yt_xxx_original_data_tmp;
DROP TEMPORARY TABLE IF EXISTS yt_xxx_staging_tmp;
```

## 编写流程（生成 SQL 时按顺序执行）

1. 先和用户确认：源表、目标表、状态字段、关联唯一键、需要聚合成 JSON 的字段、本次跑批的时间窗口
2. 套用上面"输出模板"，把占位符替换为业务字段
3. 检查清单（在交付前自检）：
   - [ ] 头部 DROP TEMPORARY TABLE 是否完整覆盖所有临时表？
   - [ ] 尾部 DROP TEMPORARY TABLE 是否完整覆盖所有临时表？
   - [ ] 每个 CREATE TEMPORARY TABLE 是否同时带 `modify_time` 时间窗口和 `LIMIT`？
   - [ ] 状态回写 UPDATE 是否 JOIN 了 Staging 表（而不是只用范围临时表 A）？
   - [ ] 是否给出了至少 5 条分步 SELECT 验证 SQL（锁定范围、补全结果、范围 vs Staging 数量对比、最终表抽样、状态分布）？
   - [ ] 所有 SQL 关键字大写、字段加反引号、注释清楚？
   - [ ] 多租户场景：是否在过滤条件里带了 `org_id`？
4. 详细的"分步验证 SELECT"模板见 [references/validation-template.md](references/validation-template.md)

## 与项目其他规范的关系

- 表 / 字段 / 索引命名遵循 `.claude/rules/mysql-database-standards.md`
- SQL 整洁度 / 注释要求遵循 `.claude/rules/sql-logic-principles.md`
- 本技能只规定"批处理 SQL 的写法"，不覆盖建表、索引设计
