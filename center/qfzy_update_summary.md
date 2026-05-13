# 2026 轮次与年度批量调整 SQL（最终版）

已按最终确认口径整理：

- 全部 `org_id = 1000936`
- 明细未下发：`task_id IS NULL`，按同 `pit_id` 已完成最新记录的轮次 `+1`
- 工单按 `task_id` 映射：`round='2026-1' -> '2025-4'`（来源条件：`annual=2026 and current_round=1`）
- 窖池按 `pit_id` 映射：更新为 `round='2025-5'`（来源条件同样为 `annual=2026 and current_round=1`，且 `task_id > 0`、`completion_time IS NOT NULL`）

---

## 1）明细表 `pct_strong_aromatic_brewing_plan_detail`

### 1.1 先查目标数据（未开始）

```sql
SELECT id, org_id, annual, current_round, task_id, pit_id
FROM pct_strong_aromatic_brewing_plan_detail
WHERE org_id = 1000936
  AND annual = 2026
  AND rec_status = 1
  AND current_round = 1
  AND task_id IS NULL;
```

### 1.2 执行更新（按 `pit_id` 最新已完成轮次 +1）

```sql
UPDATE pct_strong_aromatic_brewing_plan_detail p
JOIN (
  SELECT pit_id, annual, current_round
  FROM (
    SELECT p2.pit_id,
           p2.annual,
           p2.current_round,
           ROW_NUMBER() OVER (
             PARTITION BY p2.pit_id
             ORDER BY p2.completion_time DESC, p2.id DESC
           ) AS rn
    FROM pct_strong_aromatic_brewing_plan_detail p2
    WHERE p2.org_id = 1000936
      AND p2.rec_status = 1
      AND p2.task_id > 0
      AND p2.completion_time IS NOT NULL
      AND p2.pit_id > 0
  ) t
  WHERE t.rn = 1
) latest
  ON latest.pit_id = p.pit_id
SET p.annual = latest.annual,
    p.current_round = latest.current_round + 1,
    p.modify_time = NOW()
WHERE p.org_id = 1000936
  AND p.annual = 2026
  AND p.rec_status = 1
  AND p.current_round = 1
  AND p.task_id IS NULL
  AND p.pit_id > 0;
```

### 1.3 更新后复查

```sql
SELECT id, org_id, annual, current_round, task_id, pit_id
FROM pct_strong_aromatic_brewing_plan_detail
WHERE org_id = 1000936
  AND rec_status = 1
  AND task_id IS NULL
  AND pit_id > 0
  AND (annual, current_round) IN (
    SELECT latest.annual, latest.current_round + 1
    FROM (
      SELECT pit_id, annual, current_round
      FROM (
        SELECT p2.pit_id,
               p2.annual,
               p2.current_round,
               ROW_NUMBER() OVER (
                 PARTITION BY p2.pit_id
                 ORDER BY p2.completion_time DESC, p2.id DESC
               ) AS rn
        FROM pct_strong_aromatic_brewing_plan_detail p2
        WHERE p2.org_id = 1000936
          AND p2.rec_status = 1
          AND p2.task_id > 0
          AND p2.completion_time IS NOT NULL
          AND p2.pit_id > 0
      ) t
      WHERE t.rn = 1
    ) latest
  );
```

---

## 2）工单表 ``poit-product`.produce_work_order`

### 2.1 先查将被转换工单（2026-1 -> 2025-4）

```sql
SELECT w.id, w.org_id, w.rec_status, w.`round`
FROM `poit-product`.produce_work_order w
WHERE w.org_id = 1000936
  AND w.rec_status = 1
  AND w.`round` = '2026-1'
  AND w.id IN (
    SELECT DISTINCT p.task_id
    FROM pct_strong_aromatic_brewing_plan_detail p
    WHERE p.org_id = 1000936
      AND p.rec_status = 1
      AND p.task_id > 0
      AND p.annual = 2026
      AND p.current_round = 1
  );
```

### 2.2 执行更新

```sql
UPDATE `poit-product`.produce_work_order w
SET w.`round` = '2025-4'
WHERE w.org_id = 1000936
  AND w.rec_status = 1
  AND w.`round` = '2026-1'
  AND w.id IN (
    SELECT DISTINCT p.task_id
    FROM pct_strong_aromatic_brewing_plan_detail p
    WHERE p.org_id = 1000936
      AND p.rec_status = 1
      AND p.task_id > 0
      AND p.annual = 2026
      AND p.current_round = 1
  );
```

### 2.3 更新后复查

```sql
SELECT w.id, w.org_id, w.rec_status, w.`round`
FROM `poit-product`.produce_work_order w
WHERE w.org_id = 1000936
  AND w.rec_status = 1
  AND w.`round` = '2025-4'
  AND w.id IN (
    SELECT DISTINCT p.task_id
    FROM pct_strong_aromatic_brewing_plan_detail p
    WHERE p.org_id = 1000936
      AND p.rec_status = 1
      AND p.task_id > 0
      AND p.annual = 2026
      AND p.current_round = 1
  );
```

---

## 3）窖池表 `pbd_pit`

### 3.1 先查将被更新窖池

```sql
SELECT pit.id, pit.`round`
FROM pbd_pit pit
WHERE pit.id IN (
  SELECT DISTINCT p.pit_id
  FROM pct_strong_aromatic_brewing_plan_detail p
  WHERE p.org_id = 1000936
    AND p.annual = 2026
    AND p.rec_status = 1
    AND p.current_round = 1
    AND p.task_id > 0
    AND p.completion_time IS NOT NULL
    AND p.pit_id > 0
);
```

### 3.2 执行更新（改为 2025-5）

```sql
UPDATE pbd_pit pit
SET pit.`round` = '2025-5'
WHERE pit.id IN (
  SELECT x.pit_id
  FROM (
    SELECT DISTINCT p.pit_id
    FROM pct_strong_aromatic_brewing_plan_detail p
    WHERE p.org_id = 1000936
      AND p.annual = 2026
      AND p.rec_status = 1
      AND p.current_round = 1
      AND p.task_id > 0
      AND p.completion_time IS NOT NULL
      AND p.pit_id > 0
  ) x
);
```

### 3.3 更新后复查

```sql
SELECT pit.id, pit.`round`
FROM pbd_pit pit
WHERE pit.`round` = '2025-5'
  AND pit.id IN (
    SELECT DISTINCT p.pit_id
    FROM pct_strong_aromatic_brewing_plan_detail p
    WHERE p.org_id = 1000936
      AND p.annual = 2026
      AND p.rec_status = 1
      AND p.current_round = 1
      AND p.task_id > 0
      AND p.completion_time IS NOT NULL
      AND p.pit_id > 0
  );
```

---

## 4）最终补充查询

```sql
SELECT id, org_id, annual, current_round, task_id, pit_id
FROM pct_strong_aromatic_brewing_plan_detail
WHERE org_id = 1000936
  AND annual = 2026
  AND rec_status = 1
  AND current_round = 1
  AND task_id IS NULL;
```

---

## 5）`task_id > 0` 数据补充（2026-1 -> 2025-4）

```sql
SELECT id, org_id, annual, current_round, task_id, pit_id
FROM pct_strong_aromatic_brewing_plan_detail
WHERE org_id = 1000936
  AND annual = 2026
  AND rec_status = 1
  AND current_round = 1
  AND task_id > 0;
```

```sql
UPDATE pct_strong_aromatic_brewing_plan_detail
SET annual = 2025,
    current_round = 4,
    modify_time = NOW()
WHERE org_id = 1000936
  AND annual = 2026
  AND rec_status = 1
  AND current_round = 1
  AND task_id > 0;
```
