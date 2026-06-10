-- =============================================================
-- 用途：将 yt_mom_bghb_formal 表中按创建时间最新的10条记录
--       同步插入到 yt_wms_feeding_low 表
-- 创建时间：2026-06-10
-- =============================================================

INSERT INTO yt_wms_feeding_low (
    work_order_number, production_date, mfg, exp, material_code,
    product_line, production_batch, dw_fnumber, cost_center_orgunit,
    warehouse, tracknumber, notes, num, yt_number,
    execute_status, transaction_type
)
SELECT
    work_order_number, production_date, mfg, exp, material_code,
    product_line, production_batch, dw_fnumber, cost_center_orgunit,
    warehouse, tracknumber, notes, num, yt_number,
    execute_status, transaction_type
FROM yt_mom_bghb_formal
ORDER BY create_time DESC
LIMIT 10;
