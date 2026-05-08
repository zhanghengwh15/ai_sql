# 分步验证 SELECT 模板

任何「临时表批处理 SQL」在交付前都必须附带下面 **5 类**验证 SELECT。验证语句须写在 **`/* ... */` 块注释**中（块内为可执行 `SELECT`）：脚本随主流程一起保存，运维**删除块首尾定界符**即可整段复制执行，避免逐行去掉 `--`。

成功子集的表达有两种（与 [SKILL.md §3 / §3.1](../SKILL.md) 一致）：

| 模式 | 成功子集如何定义 | 验证 SQL-3 / SQL-5 对照谁 |
|------|------------------|---------------------------|
| **A. 范围 + Staging** | `yt_xxx_staging_tmp` 中的行 | `locked_cnt` vs `passed_cnt`（Staging 行数） |
| **B. 扩列范围 + JOIN 业务表（无 Staging）** | `UPDATE` 时 `INNER JOIN` 命中的业务表行 | `locked_cnt` vs `hit_biz_cnt`（范围表 JOIN 源表 JOIN 业务表的计数） |

> 替换说明：把模板里的 `yt_xxx_original_data` / `yt_xxx_*_tmp` / `yt_xxx_finsh_data` / `yt_xxx_biz` 换成实际表名；模式 B 时把 `yt_xxx_biz` 换成真实业务表。

---

## 模式 A（默认）：范围临时表 + Staging

### 验证 SQL-1：锁定范围检查

确认临时表 A（范围表）锁定的记录数量、典型样本是否符合预期。

```sql
/* 验证 SQL-1：锁定范围检查
SELECT COUNT(*) AS lock_cnt FROM yt_xxx_original_data_tmp;

SELECT *
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
LIMIT 20;
*/
```

### 验证 SQL-2：预处理（字段补全）结果检查

重点确认补全字段是否仍存在 NULL，NULL 行将在下一步被 Staging 表过滤掉，需要心里有数。

```sql
/* 验证 SQL-2：补全字段分布与失败行
SELECT entry_store_location_code, COUNT(*) AS cnt
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
GROUP BY entry_store_location_code;

SELECT id, receiving_warehouse_store_code, entry_store_location_code
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
  AND entry_store_location_code IS NULL;
*/
```

### 验证 SQL-3：范围 vs Staging 数量对比（最关键）

`locked_cnt - passed_cnt` 即「被各类校验过滤掉的记录数」，这部分**绝不应该被回写为成功」。这是发现「逻辑漏洞：中间没处理却 SET = 已完成」的核心检查。

```sql
/* 验证 SQL-3：范围 vs Staging 行数及样本
SELECT
  (SELECT COUNT(*) FROM yt_xxx_original_data_tmp) AS locked_cnt,
  (SELECT COUNT(*) FROM yt_xxx_staging_tmp)       AS passed_cnt;

SELECT * FROM yt_xxx_staging_tmp LIMIT 5;

SELECT docket_code,
       JSON_LENGTH(formatted_json) AS detail_cnt
FROM yt_xxx_staging_tmp
ORDER BY detail_cnt DESC
LIMIT 10;
*/
```

### 验证 SQL-4：最终表写入抽样核对

检查 `INSERT ... ON DUPLICATE KEY UPDATE` 是否真把 Staging 数据写到了目标表，以及 JSON 字段是否完整。

```sql
/* 验证 SQL-4：最终表与 Staging 关联抽样
SELECT f.docket_code, f.record_no, f.docket_detail_list
FROM yt_xxx_finsh_data f
JOIN yt_xxx_staging_tmp s ON f.docket_code = s.docket_code
LIMIT 5;

SELECT COUNT(*) FROM yt_xxx_finsh_data;
*/
```

### 验证 SQL-5：状态回写后的分布检查

确认本次锁定范围内的状态分布。理想情况：`cal_status=2` 的数量应等于与 Staging 关联成功的规模；剩下的应该仍是 `cal_status=1`（或被显式标记为 `3` 重试）。

```sql
/* 验证 SQL-5：状态分布与反向脏数据检查
SELECT cal_status, COUNT(*) AS cnt
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
GROUP BY cal_status;

SELECT m.id, m.docket_code, m.cal_status
FROM yt_xxx_original_data m
LEFT JOIN yt_xxx_staging_tmp s ON m.docket_code = s.docket_code
WHERE m.id IN (SELECT id FROM yt_xxx_original_data_tmp)
  AND s.docket_code IS NULL
  AND m.cal_status = 2;
*/
```

---

## 模式 B：扩列范围表 + `UPDATE` 直接 `JOIN` 业务表（无 Staging）

适用于无聚合、无 JSON、仅键上同步回写。范围表命名示例：`yt_xxx_scope_tmp`（含 `id`、关联键、必要载荷列）。

### 验证 SQL-1B：锁定范围（与模式 A 相同思路）

```sql
/* 验证 SQL-1B：锁定范围
SELECT COUNT(*) AS lock_cnt FROM yt_xxx_scope_tmp;

SELECT s.*, d.cal_status, d.modify_time
FROM yt_xxx_scope_tmp s
JOIN yt_xxx_original_data d ON d.id = s.id
LIMIT 20;
*/
```

### 验证 SQL-2B：预处理（若有）

若存在「只对范围内源表补字段」的步骤，同模式 A 的 SQL-2，把 `yt_xxx_original_data_tmp` 换成 `yt_xxx_scope_tmp` 与 `d.id = s.id` 关联即可；同样建议包在 **`/* ... */`** 中。

### 验证 SQL-3B：范围 vs「业务命中」数量（对应模式 A 的 SQL-3）

**无 Staging 时**，用「范围表 JOIN 源表 JOIN 业务表」的行数代替 `passed_cnt`；差额同样**不得**被回写为成功。

```sql
/* 验证 SQL-3B：locked 与 hit_biz 及样本
SELECT
  (SELECT COUNT(*) FROM yt_xxx_scope_tmp) AS locked_cnt,
  (
    SELECT COUNT(*)
    FROM yt_xxx_scope_tmp s
    JOIN yt_xxx_original_data d ON d.id = s.id
    JOIN yt_xxx_biz b ON b.biz_key = s.biz_key
    WHERE d.cal_status = 1
  ) AS hit_biz_cnt;

SELECT s.id, s.biz_key, b.id AS biz_row_id
FROM yt_xxx_scope_tmp s
JOIN yt_xxx_original_data d ON d.id = s.id
JOIN yt_xxx_biz b ON b.biz_key = s.biz_key
WHERE d.cal_status = 1
LIMIT 20;
*/
```

### 验证 SQL-4B：业务表 / 目标表抽样（对应模式 A 的 SQL-4）

```sql
/* 验证 SQL-4B：业务表抽样
SELECT b.*
FROM yt_xxx_biz b
JOIN yt_xxx_scope_tmp s ON b.biz_key = s.biz_key
LIMIT 20;
*/
```

### 验证 SQL-5B：状态回写 + 反向检查（对应模式 A 的 SQL-5）

```sql
/* 验证 SQL-5B：状态分布与反向检查（完成态、关联键按脚本替换）
SELECT d.cal_status, COUNT(*) AS cnt
FROM yt_xxx_original_data d
WHERE d.id IN (SELECT id FROM yt_xxx_scope_tmp)
GROUP BY d.cal_status;

SELECT d.id, d.biz_key, d.cal_status
FROM yt_xxx_original_data d
JOIN yt_xxx_scope_tmp s ON d.id = s.id
LEFT JOIN yt_xxx_biz b ON b.biz_key = s.biz_key
WHERE d.id IN (SELECT id FROM yt_xxx_scope_tmp)
  AND b.id IS NULL
  AND d.cal_status = 2;
*/
```

---

## 使用建议

- 上线前：在测试库上把**所选模式**下对应的 5 类验证块各执行一遍（去掉块注释定界符后），结果截图存档
- 上线后：保留这些块作为「巡检脚本」
- 若 SQL-5 / SQL-5B 中反向检查出现任何记录，**立刻回滚 / 人工修复**，并复查 `UPDATE ... JOIN` 是否与成功子集（Staging 或业务 `INNER JOIN`）一致
