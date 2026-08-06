
-- 创建临时表前先做次清除，保证表不被占用
DROP TEMPORARY TABLE IF EXISTS yt_mom_cpck_formal_tmp;

-- 创建临时表用于存放计算结果数据，读取采集结果表并联接映射表
CREATE TEMPORARY TABLE yt_mom_cpck_formal_tmp AS (
  SELECT
    mr.id
  FROM
    yt_mom_cpck_formal mr
  WHERE
    mr.calculation_status = 1
);
ALTER TABLE yt_mom_cpck_formal_tmp ADD PRIMARY KEY (id);

-- 1. 添加 WHERE 条件避免无效更新
UPDATE yt_mom_cpck_formal f
JOIN yt_mom_cpck_formal_tmp t ON f.id = t.id
SET
  f.storecode = CONCAT(f.warehousenumber,'EAS');

-- 2. 主查询优化
INSERT INTO cal_warehouse_inventory (
    warehouse,
    warehouse_code,
    unit,
    inventory_quantity,
    material_name,
    material_code,
    batch_no,
    init_time,
    source_id
)
WITH
     formal_update AS (
 SELECT
    mr.id
  FROM
    yt_mom_cpck_formal mr
  WHERE
    mr.calculation_status = 1
),
     yt_mom_cpck_formal_tmp2 AS (
  SELECT
    mr.materialcode,
    mr.warehousename
  FROM yt_mom_cpck_formal mr
  INNER JOIN formal_update tmp ON mr.id = tmp.id
         group by mr.materialcode, mr.warehousename
),
OutboundSummary AS (
    -- 按仓库 + 物料汇总出库量（不区分批次）
    SELECT
        store_name,
        material_code,
        SUM(actual_quantity) AS total_outbound_qty
    FROM yt_eas_sale_outbound_order o inner join  yt_mom_cpck_formal_tmp2 f on f.warehousename = o.store_name and f.materialcode = o.material_code
    WHERE o.biz_date >= CURDATE()
  AND o.biz_date < CURDATE() + INTERVAL 1 DAY
    GROUP BY store_name, material_code
),
       yt_mom_cpck_formal_tmp3 AS (
  SELECT
    mr.storecode,
    mr.materialcode,
    mr.flot
  FROM yt_mom_cpck_formal mr
  INNER JOIN formal_update tmp ON mr.id = tmp.id
         group by mr.storecode,mr.materialcode, mr.flot
),
InventoryWithCumulative AS (
    -- 库存数据，按 warehouse + material + flot 分组，并计算累计库存
    SELECT
        f.warehousename AS warehouse,
        f.materialcode AS material_code,
       f.materialname as      material_name,
        f.flot AS batch_no,
        f.unitname as  unit,
        f.storecode as  warehouse_code,
        f.id as id,
        f.fcreatetime AS create_time,
        f.fcurstoreqty AS store_quantity,
        IFNULL(o.total_outbound_qty, 0) as total_outbound_qty,
        SUM(f.fcurstoreqty) OVER (
            PARTITION BY f.warehousename, f.materialcode
            ORDER BY f.fcreatetime
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_inventory
    FROM yt_mom_cpck_formal f inner join  yt_mom_cpck_formal_tmp3 t2
        on f.storecode = t2.storecode and f.materialcode = t2.materialcode and f.flot = t2.flot
    LEFT JOIN OutboundSummary o
        ON f.warehousename = o.store_name
        AND f.materialcode = o.material_code
    WHERE f.rec_status = 1
      AND f.storecode IS NOT NULL
),
FIFODeduction AS (
    -- 计算每个批次应扣除的数量
    SELECT
        warehouse,
        material_code,
        material_name,
        batch_no,
        unit,
        warehouse_code,
        id,
        create_time,
        store_quantity,
        total_outbound_qty,
        LEAST(
            store_quantity,
            GREATEST(
                total_outbound_qty - (cumulative_inventory - store_quantity),
                0
            )
        ) AS deduction_amount
 FROM InventoryWithCumulative
),
    AggregatedData as ( SELECT
         MIN(f.warehouse) AS warehouse,
        f.warehouse_code AS warehouse_code,
        MIN(f.unit) AS unit,
        SUM(f.store_quantity - f.deduction_amount ) AS inventory_quantity,
        MIN(f.material_name) AS material_name,
        f.material_code AS material_code,
        f.batch_no AS batch_no,
         MIN(f.create_time) AS init_time,
        MIN(f.id) AS source_id  -- 可选：取最小 source_id
    FROM
        FIFODeduction f
         GROUP BY
     f.warehouse_code, f.material_code,  f.batch_no),

 LatestInventory AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY warehouse_code, material_code, batch_no
               ORDER BY create_time DESC
           ) AS rn
    FROM cal_warehouse_inventory
)
SELECT
    warehouse,
    warehouse_code,
    unit,
    inventory_quantity,
    material_name,
    material_code,
    batch_no,
    init_time,
    source_id
FROM
    AggregatedData a
WHERE NOT EXISTS (
    SELECT 1
    FROM LatestInventory i
    WHERE  i.rn = 1
        and i.warehouse_code = a.warehouse_code
        AND i.material_code = a.material_code
        AND i.batch_no = a.batch_no
        and i.inventory_quantity = a.inventory_quantity
);
-- 将计算状态改成2，条件为库位storecode不为空，完成计算可以出仓。
UPDATE yt_mom_cpck_formal f
JOIN yt_mom_cpck_formal_tmp t ON f.id = t.id
SET f.calculation_status = 2;
-- 删除创建的临时表
DROP TEMPORARY TABLE IF EXISTS yt_mom_cpck_formal_tmp;

