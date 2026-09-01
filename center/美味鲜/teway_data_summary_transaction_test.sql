-- teway_data_summary 已存在，本脚本只执行可独立运行的 DML 和查询

DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_staging_tmp`;

-- 1. 完整成功：新增、修改、查询，交由组件提交

DELETE FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000101;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `request_message`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES (
  0, 0, 980000101, 'TX_CASE_01', '完整提交测试',
  0, '待响应', 'TX_TEST_CLIENT', 'TEWAY',
  'TX-WO-01', 'TX-DOC-01', '{"case":"01","action":"create"}', 'TX-FACTORY', 980001, 'TX_TEST_EID_20260901',
  'MAT-CASE-01', '事务测试物料一', 'BATCH-01', '10.000', 'IN',
  'VOUCHER-01', 'IN-01', 'OUT-01', 98000001
);

UPDATE `teway_data_summary`
SET `response_status` = 200,
    `response_message` = 'CASE_01_COMMITTED',
    `response_time` = NOW(),
    `datasyn_third_status` = 2,
    `datasyn_third_msg` = '同步成功',
    `modify_by` = 0,
    `modify_time` = NOW()
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000101
  AND `rec_status` = 1
  AND `response_status` = 0;

SELECT `id`, `data_id`, `response_status`, `response_message`, `datasyn_third_status`
FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000101;

-- 2. 复杂成功：临时表聚合、写入汇总、回写明细与删除后提交

DELETE FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` BETWEEN 980000201 AND 980000299;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES
  (
    0, 0, 980000201, 'TX_CASE_02_DETAIL', '复杂测试明细一',
    0, '待汇总', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-01', 'TX-FACTORY', 980001, 'TX_TEST_EID_20260901',
    'MAT-CASE-02', '事务测试物料二', 'BATCH-02-A', '10.500', 'IN',
    'VOUCHER-02-01', 'IN-02', 'OUT-02', 98000002
  ),
  (
    0, 0, 980000202, 'TX_CASE_02_DETAIL', '复杂测试明细二',
    0, '待汇总', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-02', 'TX-FACTORY', 980001, 'TX_TEST_EID_20260901',
    'MAT-CASE-02', '事务测试物料二', 'BATCH-02-B', '9.500', 'IN',
    'VOUCHER-02-02', 'IN-02', 'OUT-02', 98000002
  ),
  (
    0, 0, 980000299, 'TX_CASE_02_OBSOLETE', '待删除测试数据',
    0, '待删除', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-OBSOLETE', 'TX-FACTORY', 980001, 'TX_TEST_EID_20260901',
    'MAT-OBSOLETE', '待删除物料', 'BATCH-OBSOLETE', '1.000', 'OUT',
    'VOUCHER-02-OBSOLETE', '', 'OUT-02', 98000002
  );

CREATE TEMPORARY TABLE `teway_data_summary_scope_tmp` AS
SELECT
  `d`.`id`, `d`.`data_id`, `d`.`work_order_number`, `d`.`material_code`, `d`.`material_name`,
  `d`.`material_batch_no`, CAST(`d`.`total_quantity` AS DECIMAL(18, 3)) AS `quantity`,
  `d`.`create_by`, `d`.`eid`, `d`.`org_id`, `d`.`factory_area_code`
FROM `teway_data_summary` `d`
WHERE `d`.`eid` = 'TX_TEST_EID_20260901'
  AND `d`.`data_id` BETWEEN 980000201 AND 980000202
  AND `d`.`business_type` = 'TX_CASE_02_DETAIL'
  AND `d`.`rec_status` = 1
  AND `d`.`response_status` = 0
  AND CAST(`d`.`total_quantity` AS DECIMAL(18, 3)) > 0;

CREATE TEMPORARY TABLE `teway_data_summary_staging_tmp` AS
SELECT
  `work_order_number`,
  `material_code`,
  ANY_VALUE(`material_name`) AS `material_name`,
  MIN(`data_id`) AS `source_data_id`,
  SUM(`quantity`) AS `total_quantity`,
  COUNT(*) AS `detail_count`,
  JSON_ARRAYAGG(
    JSON_OBJECT(
      'dataId', `data_id`,
      'batchNo', `material_batch_no`,
      'quantity', `quantity`
    )
  ) AS `detail_json`,
  ANY_VALUE(`create_by`) AS `create_by`,
  ANY_VALUE(`eid`) AS `eid`,
  ANY_VALUE(`org_id`) AS `org_id`,
  ANY_VALUE(`factory_area_code`) AS `factory_area_code`
FROM `teway_data_summary_scope_tmp`
GROUP BY `work_order_number`, `material_code`;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `request_message`, `factory_area_code`, `org_id`, `eid`,
  `datasyn_third_status`, `material_code`, `material_name`, `material_batch_no`, `total_quantity`,
  `handle_type`, `material_voucher`, `entry_store_code`, `out_store_code`, `ext_field1`, `ext_field2`,
  `task_record_id`
)
SELECT
  `create_by`, `create_by`, 980000250, 'TX_CASE_02_RESULT', '复杂测试汇总结果',
  200, CONCAT('汇总成功，明细数=', `detail_count`), 'TX_TEST_CLIENT', 'TEWAY',
  `work_order_number`, CONCAT('TX-SUM-', `source_data_id`), `detail_json`, `factory_area_code`, `org_id`, `eid`,
  2, `material_code`, `material_name`, 'SUMMARY', CAST(`total_quantity` AS CHAR),
  'SUMMARY', CONCAT('SUMMARY-', `source_data_id`), 'IN-02', 'OUT-02', 'RESULT',
  CAST(`detail_count` AS CHAR), 98000002
FROM `teway_data_summary_staging_tmp`;

UPDATE `teway_data_summary` `d`
INNER JOIN `teway_data_summary` `r`
  ON `r`.`eid` = `d`.`eid`
 AND `r`.`data_id` = 980000250
 AND `r`.`business_type` = 'TX_CASE_02_RESULT'
 AND `r`.`response_status` = 200
INNER JOIN `teway_data_summary_scope_tmp` `s`
  ON `s`.`id` = `d`.`id`
INNER JOIN `teway_data_summary_staging_tmp` `st`
  ON `st`.`work_order_number` = `s`.`work_order_number`
 AND `st`.`material_code` = `s`.`material_code`
SET `d`.`response_status` = 200,
    `d`.`response_message` = 'CASE_02_DETAIL_COMMITTED',
    `d`.`response_time` = NOW(),
    `d`.`datasyn_third_status` = 2,
    `d`.`datasyn_third_msg` = '已汇总',
    `d`.`modify_by` = 0,
    `d`.`modify_time` = NOW()
WHERE `d`.`rec_status` = 1
  AND `d`.`response_status` = 0
  AND `d`.`eid` = 'TX_TEST_EID_20260901'
  AND `d`.`data_id` BETWEEN 980000201 AND 980000202
  AND `d`.`business_type` = 'TX_CASE_02_DETAIL';

DELETE FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000299
  AND `business_type` = 'TX_CASE_02_OBSOLETE'
  AND `response_status` = 0;

DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_staging_tmp`;

SELECT `data_id`, `business_type`, `response_status`, `total_quantity`, `response_message`
FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` BETWEEN 980000201 AND 980000299
ORDER BY `data_id`;

-- 3. 故意执行错误 SQL：组件捕获异常后应回滚本场景的全部 DML

DELETE FROM `teway_data_summary`
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000301;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES (
  0, 0, 980000301, 'TX_CASE_03', '应回滚的数据',
  0, '执行中', 'TX_TEST_CLIENT', 'TEWAY',
  'TX-WO-03', 'TX-DOC-03', 'TX-FACTORY', 980001, 'TX_TEST_EID_20260901',
  'MAT-CASE-03', '事务测试物料三', 'BATCH-03', '3.000', 'IN',
  'VOUCHER-03', 'IN-03', 'OUT-03', 98000003
);

UPDATE `teway_data_summary`
SET `response_status` = 202,
    `response_message` = '此修改必须回滚',
    `modify_by` = 0,
    `modify_time` = NOW()
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000301
  AND `response_status` = 0;

UPDATE `teway_data_summary`
SET `not_exists_column` = 1
WHERE `eid` = 'TX_TEST_EID_20260901'
  AND `data_id` = 980000301;

DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_staging_tmp`;
