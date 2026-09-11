
UPDATE `mes_sauce_batch_output`
SET `real_quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 1  and batch_start_time >='2026-06-01 00:00:00'
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;

UPDATE `mes_yx_sauce_wrap_batch_output`
SET `real_quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 1 and batch_start_time >='2026-06-01 00:00:00'
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;

UPDATE `mes_yx_sauce_batch_output`
SET `real_quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 1 and batch_start_time >='2026-06-01 00:00:00'
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;

UPDATE `mes_sauce_wrap_batch_output`
SET `real_quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 1 and batch_start_time >='2026-06-01 00:00:00'
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;
-- mes_sauce_disk_batch_output


UPDATE `mes_sauce_disk_batch_output`
SET `real_quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 1 and batch_start_time >='2026-06-01 00:00:00'
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;

-- 重新出厂：按单位重新计算状态
UPDATE `mes_sauce_batch_output`
SET `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 3;

UPDATE `mes_yx_sauce_wrap_batch_output`
SET `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 3;

UPDATE `mes_yx_sauce_batch_output`
SET `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 3;

UPDATE `mes_sauce_wrap_batch_output`
SET `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 3;

UPDATE `mes_sauce_disk_batch_output`
SET `out_status` = CASE WHEN `unit_name` IN ('千克', '吨') THEN 2 ELSE 9 END
WHERE `out_status` = 3;
