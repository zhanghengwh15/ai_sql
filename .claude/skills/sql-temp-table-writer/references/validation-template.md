# 分步验证 SELECT 模板

任何"临时表批处理 SQL"在交付前都必须附带下面 5 类验证 SELECT。验证 SQL 以**注释形式**直接放在每段 DDL/DML 之后即可，无需让脚本自动执行 —— 它的目的是让运维 / 开发上线前手工跑一遍，确认数据符合预期。

> 替换说明：把模板里的 `yt_xxx_original_data` / `yt_xxx_staging_tmp` / `yt_xxx_finsh_data` 替换成实际表名即可。

## 验证 SQL-1：锁定范围检查

确认临时表 A（范围表）锁定的记录数量、典型样本是否符合预期。

```sql
-- 锁定的记录总数
SELECT COUNT(*) AS lock_cnt FROM yt_xxx_original_data_tmp;

-- 抽样 20 条，肉眼检查 cal_status / batch_no / modify_time 是否都是预期值
SELECT *
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
LIMIT 20;
```

## 验证 SQL-2：预处理（字段补全）结果检查

重点确认补全字段是否仍存在 NULL，NULL 行将在下一步被 Staging 表过滤掉，需要心里有数。

```sql
-- 补全字段 NULL/非 NULL 分布
SELECT entry_store_location_code, COUNT(*) AS cnt
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
GROUP BY entry_store_location_code;

-- 列出所有补全失败（仍为 NULL）的记录，用于排查 CASE 分支不全
SELECT id, receiving_warehouse_store_code, entry_store_location_code
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
  AND entry_store_location_code IS NULL;
```

## 验证 SQL-3：范围 vs Staging 数量对比（最关键）

`locked_cnt - passed_cnt` 即"被各类校验过滤掉的记录数"，这部分**绝不应该被回写为成功**。这是发现"逻辑漏洞：中间没处理却 SET = 已完成"的核心检查。

```sql
-- 范围 vs Staging 行数对比
SELECT
  (SELECT COUNT(*) FROM yt_xxx_original_data_tmp)  AS locked_cnt,
  (SELECT COUNT(*) FROM yt_xxx_staging_tmp)        AS passed_cnt;

-- 看看 Staging 表的样本数据，特别是 JSON 字段是否拼装正确
SELECT * FROM yt_xxx_staging_tmp LIMIT 5;

-- 如果聚合维度是 docket_code，可统计每个 docket_code 聚合了多少条明细
SELECT docket_code,
       JSON_LENGTH(formatted_json) AS detail_cnt
FROM yt_xxx_staging_tmp
ORDER BY detail_cnt DESC
LIMIT 10;
```

## 验证 SQL-4：最终表写入抽样核对

检查 INSERT ... ON DUPLICATE KEY UPDATE 是否真把 Staging 数据写到了目标表，以及 JSON 字段是否完整。

```sql
-- 与 Staging 关联抽样
SELECT f.docket_code, f.record_no, f.docket_detail_list
FROM yt_xxx_finsh_data f
JOIN yt_xxx_staging_tmp s ON f.docket_code = s.docket_code
LIMIT 5;

-- 比对最终表行数变化（执行前后各跑一次）
SELECT COUNT(*) FROM yt_xxx_finsh_data;
```

## 验证 SQL-5：状态回写后的分布检查

确认本次锁定范围内的状态分布。理想情况：`cal_status=2` 的数量应等于 Staging 行对应的明细数；剩下的应该仍是 `cal_status=1`（或被显式标记为 `3` 重试）。

```sql
-- 锁定范围内的状态分布
SELECT cal_status, COUNT(*) AS cnt
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
GROUP BY cal_status;

-- 反向检查：是否存在"未进入 Staging 但被回写为成功"的脏数据
SELECT m.id, m.docket_code, m.cal_status
FROM yt_xxx_original_data m
LEFT JOIN yt_xxx_staging_tmp s ON m.docket_code = s.docket_code
WHERE m.id IN (SELECT id FROM yt_xxx_original_data_tmp)
  AND s.docket_code IS NULL          -- 未进入 Staging
  AND m.cal_status = 2;              -- 却被标记成功 → 必定是脚本逻辑错误
```

## 使用建议

- 上线前：在测试库上把全部 5 类 SELECT 跑一遍，结果截图存档
- 上线后：保留这些 SELECT 作为"巡检脚本"，用于排查跑批异常
- 如果 SQL-5 的"反向检查"出现任何记录，**立刻回滚 / 人工修复**，并复查 `UPDATE ... JOIN staging_tmp` 是否被改坏
