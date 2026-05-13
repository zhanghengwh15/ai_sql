# 2025-4 窖池未下发轮次修正 SQL

口径说明（按本次需求）：

- 目标数据：`pct_strong_aromatic_brewing_plan_detail`
- 目标范围：`annual = 2025 AND rec_status = 1 AND current_round = 4 AND task_id IS NULL`
- 取值逻辑：按同 `pit_id` 在跨库表 `` `poit-product`.produce_work_order `` 中，取最大轮次（`round` 形如 `2025-4`，仅取 `-` 后数字）+1，回写到 `current_round`
- 不使用临时表，直接 `JOIN` 更新

---

## 1）更新前核对（仅显示 `next_round <> current_round`）

```sql
SELECT
  p.id,
  p.org_id,
  p.pit_id,
  pit.`name` AS pit_name,
  pit.`code` AS pit_code,
  p.annual,
  p.current_round,
  p.task_id,
  w.execute_status,
  w.raw_round,
  w.round_num,
  w.round_num + 1 AS next_round
FROM pct_strong_aromatic_brewing_plan_detail p
LEFT JOIN pbd_pit pit
  ON pit.id = p.pit_id
 AND pit.rec_status = 1
LEFT JOIN (
  SELECT
    t.pit_id,
    t.execute_status,
    t.raw_round,
    t.round_num
  FROM (
    SELECT
      pwo.pit_id,
      pwo.execute_status,
      pwo.`round` AS raw_round,
      CAST(SUBSTRING_INDEX(pwo.`round`, '-', -1) AS UNSIGNED) AS round_num,
      ROW_NUMBER() OVER (
        PARTITION BY pwo.pit_id
        ORDER BY CAST(SUBSTRING_INDEX(pwo.`round`, '-', -1) AS UNSIGNED) DESC, pwo.id DESC
      ) AS rn
    FROM `poit-product`.produce_work_order pwo
    WHERE pwo.rec_status = 1
      AND pwo.pit_id > 0
      AND pwo.`round` REGEXP '^[0-9]+-[0-9]+$'
  ) t
  WHERE t.rn = 1
) w ON w.pit_id = p.pit_id
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id IS NULL
  AND w.round_num IS NOT NULL
  AND w.round_num + 1 <> p.current_round
  and w.round_num + 1 = 3
ORDER BY p.pit_id, p.id;
```

---

## 2）执行更新（先取 ID，再按 ID 更新）

### 2.1 获取需要更新的 `id` 与目标轮次

```sql
SELECT
  p.id,
  p.current_round AS old_current_round,
  w.max_round + 1 AS new_current_round
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN (
  SELECT
    pwo.pit_id,
    MAX(CAST(SUBSTRING_INDEX(pwo.`round`, '-', -1) AS UNSIGNED)) AS max_round
  FROM `poit-product`.produce_work_order pwo
  WHERE pwo.rec_status = 1
    AND pwo.pit_id > 0
    AND pwo.`round` REGEXP '^[0-9]+-[0-9]+$'
  GROUP BY pwo.pit_id
) w ON w.pit_id = p.pit_id
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id IS NULL
  AND w.max_round + 1 <> p.current_round
ORDER BY p.id;
```

### 2.2 按 `id` 执行更新（把下方 ID 列表替换为上一步结果）

```sql
UPDATE pct_strong_aromatic_brewing_plan_detail p
JOIN (
  SELECT
    pwo.pit_id,
    MAX(CAST(SUBSTRING_INDEX(pwo.`round`, '-', -1) AS UNSIGNED)) AS max_round
  FROM `poit-product`.produce_work_order pwo
  WHERE pwo.rec_status = 1
    AND pwo.pit_id > 0
    AND pwo.`round` REGEXP '^[0-9]+-[0-9]+$'
  GROUP BY pwo.pit_id
) w ON w.pit_id = p.pit_id
SET p.current_round = w.max_round + 1,
    p.modify_time = NOW()
WHERE p.id IN (/* 填入 2.1 查询出的 id，逗号分隔 */)
  AND p.annual = 2025
  AND p.rec_status = 1
  AND p.task_id IS NULL
  AND w.max_round + 1 <> p.current_round;
```

---

## 3）更新后复核

```sql
SELECT
  p.id,
  p.org_id,
  p.pit_id,
  pit.`name` AS pit_name,
  pit.`code` AS pit_code,
  p.annual,
  p.current_round,
  p.task_id
FROM pct_strong_aromatic_brewing_plan_detail p
LEFT JOIN pbd_pit pit
  ON pit.id = p.pit_id
 AND pit.rec_status = 1
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.task_id IS NULL
ORDER BY p.pit_id, p.id;
```

```sql
SELECT ROW_COUNT() AS affected_rows;
```

---

## 4）可选：仅预演影响范围（不落库）

```sql
SELECT COUNT(1) AS will_update_rows
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN (
  SELECT
    pwo.pit_id,
    MAX(CAST(SUBSTRING_INDEX(pwo.`round`, '-', -1) AS UNSIGNED)) AS max_round
  FROM `poit-product`.produce_work_order pwo
  WHERE pwo.rec_status = 1
    AND pwo.pit_id > 0
    AND pwo.`round` REGEXP '^[0-9]+-[0-9]+$'
  GROUP BY pwo.pit_id
) w ON w.pit_id = p.pit_id
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id IS NULL
  AND w.max_round + 1 <> p.current_round;
```

---

## 5）已下发数据处理（`task_id > 0`）：`2024-4 -> 2024-3`

口径：基于 `pct_strong_aromatic_brewing_plan_detail` 条件

- `annual = 2025`
- `rec_status = 1`
- `current_round = 4`
- `task_id > 0`

对对应 `pit_id` 判断：若在 `` `poit-product`.produce_work_order `` 中**不存在**
`round = '2025-3' AND execute_status IN (2,4)` 的记录，则将目标工单轮次从 `2024-4` 调整为 `2024-3`。

### 5.1 先查目标数据（不做存在性过滤）

```sql
SELECT
  p.id AS plan_detail_id,
  p.task_id AS work_order_id,
  p.pit_id,
  pit.`name` AS pit_name,
  pit.`code` AS pit_code,
  w.`round` AS old_round
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN `poit-product`.produce_work_order w
  ON w.id = p.task_id
 AND w.rec_status = 1
LEFT JOIN pbd_pit pit
  ON pit.id = p.pit_id
 AND pit.rec_status = 1
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id > 0
ORDER BY p.pit_id, p.id;
```

### 5.2 在上述结果中标记“是否存在 2025-3 且 execute_status in (2,4)”

```sql
SELECT
  p.id AS plan_detail_id,
  p.task_id AS work_order_id,
  p.pit_id,
  pit.`name` AS pit_name,
  pit.`code` AS pit_code,
  w.`round` AS old_round,
  CASE
    WHEN EXISTS (
      SELECT 1
      FROM `poit-product`.produce_work_order w2
      WHERE w2.rec_status = 1
        AND w2.pit_id = p.pit_id
        AND w2.`round` = '2025-3'
        AND w2.execute_status IN (0,1,2, 4)
    ) THEN 1
    ELSE 0
  END AS has_2025_3_done_or_closed
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN `poit-product`.produce_work_order w
  ON w.id = p.task_id
 AND w.rec_status = 1
LEFT JOIN pbd_pit pit
  ON pit.id = p.pit_id
 AND pit.rec_status = 1
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id > 0
ORDER BY p.pit_id, p.id;
```

### 5.3 仅查看需更新的数据（不存在则更新：`2024-4 -> 2024-3`）

```sql
SELECT
  p.id AS plan_detail_id,
  p.task_id AS work_order_id,
  p.pit_id,
  pit.`name` AS pit_name,
  pit.`code` AS pit_code,
  w.`round` AS old_round,
  '2024-3' AS new_round
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN `poit-product`.produce_work_order w
  ON w.id = p.task_id
 AND w.rec_status = 1
LEFT JOIN pbd_pit pit
  ON pit.id = p.pit_id
 AND pit.rec_status = 1
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id > 0
  AND w.`round` = '2024-4'
  AND NOT EXISTS (
    SELECT 1
    FROM `poit-product`.produce_work_order w2
    WHERE w2.rec_status = 1
      AND w2.pit_id = p.pit_id
      AND w2.`round` = '2025-3'
      AND w2.execute_status IN (2, 4)
  )
ORDER BY p.pit_id, p.id;
```

### 5.4 执行更新（仅更新满足条件的工单）

```sql
UPDATE `poit-product`.produce_work_order w
JOIN pct_strong_aromatic_brewing_plan_detail p
  ON p.task_id = w.id
 AND p.annual = 2025
 AND p.rec_status = 1
 AND p.current_round = 4
 AND p.task_id > 0
SET w.`round` = '2024-3',
    w.modify_time = NOW()
WHERE w.rec_status = 1
  AND w.`round` = '2024-4'
  AND NOT EXISTS (
    SELECT 1
    FROM `poit-product`.produce_work_order w2
    WHERE w2.rec_status = 1
      AND w2.pit_id = p.pit_id
      AND w2.`round` = '2025-3'
      AND w2.execute_status IN (2, 4)
  );
```

### 5.5 更新后复核

```sql
SELECT
  p.id AS plan_detail_id,
  p.task_id AS work_order_id,
  p.pit_id,
  w.`round`,
  w.execute_status
FROM pct_strong_aromatic_brewing_plan_detail p
JOIN `poit-product`.produce_work_order w
  ON w.id = p.task_id
 AND w.rec_status = 1
WHERE p.annual = 2025
  AND p.rec_status = 1
  AND p.current_round = 4
  AND p.task_id > 0
  AND w.`round` = '2024-3'
ORDER BY p.pit_id, p.id;
```
