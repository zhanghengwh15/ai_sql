-- 美味鲜生产：仅修改 3 条 TEST000000 测试物料的单位标签，不换算数量。
UPDATE `material`
SET `measure_unit` = '吨',
    `unit` = '吨'
WHERE `rec_status` = 1
  AND `org_id` IN (100002, 100003, 100004)
  AND `code` = 'TEST000000'
  AND `measure_unit` = '箱(12)'
  AND `unit` = '箱(12)'
  AND `material_id` IN (105107, 105108, 105109);
