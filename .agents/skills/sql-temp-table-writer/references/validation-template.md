# 分步验证 SELECT 模板

仅在用户明确要求时提供验证 SQL。将所需查询作为独立可执行 SQL 输出，不使用 `/* ... */`、`--` 或行内注释，也不默认添加 `LIMIT`。

成功子集的表达有两种：

| 模式 | 成功子集如何定义 | 数量对照 |
|------|------------------|----------|
| A. 范围 + Staging | `yt_xxx_staging_tmp` 中的行 | `locked_cnt` 与 `passed_cnt` |
| B. 扩列范围 + JOIN 业务表 | `UPDATE` 时 `INNER JOIN` 命中的业务表行 | `locked_cnt` 与 `hit_biz_cnt` |

把模板中的 `yt_xxx_original_data`、`yt_xxx_*_tmp`、`yt_xxx_finsh_data` 和 `yt_xxx_biz` 替换为实际表名。

## 模式 A：范围临时表 + Staging

### 验证 1：锁定范围

```sql
SELECT COUNT(*) AS lock_cnt
FROM yt_xxx_original_data_tmp;

SELECT *
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp);
```

### 验证 2：预处理结果

```sql
SELECT entry_store_location_code, COUNT(*) AS cnt
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
GROUP BY entry_store_location_code;

SELECT id, receiving_warehouse_store_code, entry_store_location_code
FROM yt_xxx_original_data
WHERE id IN (SELECT id FROM yt_xxx_original_data_tmp)
  AND entry_store_location_code IS NULL;
```

### 验证 3：范围与 Staging 数量

`locked_cnt - passed_cnt` 是被校验过滤的记录数，不能回写为成功。

```sql
SELECT
  (SELECT COUNT(*) FROM yt_xxx_original_data_tmp) AS locked_cnt,
  (SELECT COUNT(*) FROM yt_xxx_staging_tmp) AS passed_cnt;

SELECT *
FROM yt_xxx_staging_tmp;

SELECT docket_code, JSON_LENGTH(formatted_json) AS detail_cnt
FROM yt_xxx_staging_tmp
ORDER BY detail_cnt DESC;
```

### 验证 4：最终表写入

```sql
SELECT f.docket_code, f.record_no, f.docket_detail_list
FROM yt_xxx_finsh_data f
JOIN yt_xxx_staging_tmp s ON f.docket_code = s.docket_code;

SELECT COUNT(*)
FROM yt_xxx_finsh_data;
```

### 验证 5：状态回写

```sql
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
```

## 模式 B：扩列范围表 + 直接 JOIN 业务表

适用于无聚合、无 JSON、仅键上同步回写。范围表命名示例为 `yt_xxx_scope_tmp`，包含 `id`、关联键和必要载荷列。

### 验证 1：锁定范围

```sql
SELECT COUNT(*) AS lock_cnt
FROM yt_xxx_scope_tmp;

SELECT s.*, d.cal_status, d.modify_time
FROM yt_xxx_scope_tmp s
JOIN yt_xxx_original_data d ON d.id = s.id;
```

### 验证 2：预处理结果

```sql
SELECT d.entry_store_location_code, COUNT(*) AS cnt
FROM yt_xxx_original_data d
JOIN yt_xxx_scope_tmp s ON d.id = s.id
GROUP BY d.entry_store_location_code;

SELECT d.id, d.receiving_warehouse_store_code, d.entry_store_location_code
FROM yt_xxx_original_data d
JOIN yt_xxx_scope_tmp s ON d.id = s.id
WHERE d.entry_store_location_code IS NULL;
```

### 验证 3：范围与业务命中数量

```sql
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
WHERE d.cal_status = 1;
```

### 验证 4：业务表结果

```sql
SELECT b.*
FROM yt_xxx_biz b
JOIN yt_xxx_scope_tmp s ON b.biz_key = s.biz_key;
```

### 验证 5：状态回写

```sql
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
```

## 维护说明

- 该文件仅提供用户明确要求时的独立验证 SQL，不得将其恢复为主流程的必带内容。
- 不要为这些查询增加块注释、行内注释、分隔线或默认 `LIMIT`；需要缩小结果范围时由用户明确指定。
- 若反向检查返回记录，检查状态回写的 `JOIN` 条件是否与成功子集一致。
