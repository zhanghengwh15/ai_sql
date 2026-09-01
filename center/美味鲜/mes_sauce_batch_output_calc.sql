-- =====================================================================
-- 业务名称：美味鲜酱油批次产量单位换算计算任务
-- 主表：    mes_sauce_batch_output
-- 触发方式：定时计算任务
-- 数据库：  MySQL 8
-- 说明：    仅处理 out_status = 1 且最近 1 天内修改的待计算数据；
--          单位名称为“千克”时，quantity 除以 1000，否则保持不变；
--          处理完成后统一将 out_status 更新为 2。
-- =====================================================================

UPDATE `mes_sauce_batch_output`
SET `quantity` = CASE
        WHEN `unit_name` = '千克' THEN `quantity` / 1000
        ELSE `quantity`
    END,
    `out_status` = 2
WHERE `out_status` = 1
    AND `modify_time` >= NOW() - INTERVAL 1 DAY;
