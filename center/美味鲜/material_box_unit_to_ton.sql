-- 美味鲜生产：修改所有符合条件的箱装物料单位标签，不换算数量。
UPDATE `material`
SET `measure_unit` = '吨',
    `unit` = '吨'
WHERE `rec_status` = 1
  AND `org_id` IN (100002, 100003, 100004)
  AND `measure_unit` LIKE '箱(%)'
  AND NOT (`measure_unit` <=> '吨' AND `unit` <=> '吨');
