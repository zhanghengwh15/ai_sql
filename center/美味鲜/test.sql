UPDATE `mes_yx_sauce_wrap_batch_output`
SET `quantity`  = IF(`unit_name` = '千克', `quantity` / 1000, `quantity`),
    `unit_name` = IF(`unit_name` = '千克', '吨', `unit_name`),
    `out_status` = 2
WHERE `out_status` = 1
  AND `modify_time` >= NOW() - INTERVAL 1 DAY;
