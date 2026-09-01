-- teway_data_summary 事务测试脚本，依赖已存在的 mid_iam_user 表

CREATE TABLE IF NOT EXISTS `teway_data_summary` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键id',
  `rec_status` tinyint(1) DEFAULT 1 COMMENT '逻辑删除(0:删除，1:有效)',
  `create_by` bigint DEFAULT 0 COMMENT '创建人',
  `create_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_by` bigint DEFAULT 0 COMMENT '修改人',
  `modify_time` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `data_id` bigint DEFAULT 0 COMMENT '数据唯一标识ID',
  `business_type` varchar(255) DEFAULT '' COMMENT '业务类型',
  `business_name` varchar(256) DEFAULT '' COMMENT '业务名称',
  `response_status` bigint DEFAULT 0 COMMENT '响应状态',
  `response_message` varchar(2000) DEFAULT '' COMMENT '响应消息',
  `response_time` datetime DEFAULT CURRENT_TIMESTAMP COMMENT '响应时间',
  `request_system` varchar(64) DEFAULT '' COMMENT '请求系统',
  `response_system` varchar(64) DEFAULT '' COMMENT '响应系统',
  `work_order_number` varchar(64) DEFAULT '' COMMENT '生产工单号',
  `document_code` varchar(256) DEFAULT '' COMMENT '单据编码',
  `request_message` varchar(2000) DEFAULT '' COMMENT '请求消息',
  `factory_area_code` varchar(128) DEFAULT '' COMMENT '工厂编码',
  `org_id` bigint DEFAULT 0 COMMENT '组织ID',
  `eid` varchar(255) DEFAULT '' COMMENT '企业ID',
  `datasyn_third_status` bigint DEFAULT 1 COMMENT '同步第三方表状态',
  `datasyn_third_msg` varchar(2000) DEFAULT '' COMMENT '同步第三方表返回信息',
  `material_code` varchar(100) NOT NULL DEFAULT '' COMMENT '物料编码',
  `material_name` varchar(100) NOT NULL DEFAULT '' COMMENT '物料名称',
  `material_batch_no` varchar(100) NOT NULL DEFAULT '' COMMENT '物料批次',
  `total_quantity` varchar(100) NOT NULL DEFAULT '' COMMENT '汇总数量',
  `handle_type` varchar(100) NOT NULL DEFAULT '' COMMENT '类型',
  `material_voucher` varchar(100) NOT NULL DEFAULT '' COMMENT '物料凭证',
  `entry_store_code` varchar(100) NOT NULL DEFAULT '' COMMENT '(入库)仓库编码',
  `entry_store_name` varchar(100) NOT NULL DEFAULT '' COMMENT '(入库)仓库名称',
  `out_store_code` varchar(100) NOT NULL DEFAULT '' COMMENT '(出库)仓库编码',
  `out_store_name` varchar(100) NOT NULL DEFAULT '' COMMENT '(出库)仓库名称',
  `ext_field1` varchar(100) NOT NULL DEFAULT '' COMMENT '扩展字段1',
  `ext_field2` varchar(100) NOT NULL DEFAULT '' COMMENT '扩展字段2',
  `task_record_id` bigint DEFAULT 0 COMMENT '任务单 Id',
  PRIMARY KEY (`id`),
  KEY `idx_dataid` (`data_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='[天味] 同步第三方数据汇总表';

-- 0. 初始化可重复执行的测试用户和测试数据
SET @teway_test_eid := 'TX_TEST_EID_20260901';
SET @teway_test_username := 'tx_test_operator_20260901';

START TRANSACTION;

DELETE FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` BETWEEN 980000001 AND 980000999;

DELETE FROM `mid_iam_user`
WHERE `eid` = @teway_test_eid
  AND `username` = @teway_test_username;

INSERT INTO `mid_iam_user` (
  `username`, `full_name`, `company_id`, `organization_id`, `is_disabled`, `rec_status`, `eid`
)
VALUES (
  @teway_test_username, '事务测试操作人', 'TX_TEST_COMPANY', 'TX_TEST_ORG', 0, 1, @teway_test_eid
);

SET @teway_test_user_id := LAST_INSERT_ID();

COMMIT;

SELECT `id`, `username`, `full_name`, `eid`
FROM `mid_iam_user`
WHERE `id` = @teway_test_user_id;

-- 1. 完整成功：新增、修改、查询后提交
START TRANSACTION;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `request_message`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES (
  @teway_test_user_id, @teway_test_user_id, 980000101, 'TX_CASE_01', '完整提交测试',
  0, '待响应', 'TX_TEST_CLIENT', 'TEWAY',
  'TX-WO-01', 'TX-DOC-01', '{"case":"01","action":"create"}', 'TX-FACTORY', 980001, @teway_test_eid,
  'MAT-CASE-01', '事务测试物料一', 'BATCH-01', '10.000', 'IN',
  'VOUCHER-01', 'IN-01', 'OUT-01', 98000001
);

UPDATE `teway_data_summary`
SET `response_status` = 200,
    `response_message` = 'CASE_01_COMMITTED',
    `response_time` = NOW(),
    `datasyn_third_status` = 2,
    `datasyn_third_msg` = '同步成功',
    `modify_by` = @teway_test_user_id,
    `modify_time` = NOW()
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000101
  AND `rec_status` = 1
  AND `response_status` = 0;

SELECT `id`, `data_id`, `response_status`, `response_message`, `datasyn_third_status`
FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000101;

COMMIT;

SELECT `id`, `data_id`, `response_status`, `response_message`, `datasyn_third_status`
FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000101;

-- 2. 复杂成功：临时表聚合、写入汇总、回写明细与删除后提交
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_staging_tmp`;

START TRANSACTION;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES
  (
    @teway_test_user_id, @teway_test_user_id, 980000201, 'TX_CASE_02_DETAIL', '复杂测试明细一',
    0, '待汇总', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-01', 'TX-FACTORY', 980001, @teway_test_eid,
    'MAT-CASE-02', '事务测试物料二', 'BATCH-02-A', '10.500', 'IN',
    'VOUCHER-02-01', 'IN-02', 'OUT-02', 98000002
  ),
  (
    @teway_test_user_id, @teway_test_user_id, 980000202, 'TX_CASE_02_DETAIL', '复杂测试明细二',
    0, '待汇总', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-02', 'TX-FACTORY', 980001, @teway_test_eid,
    'MAT-CASE-02', '事务测试物料二', 'BATCH-02-B', '9.500', 'IN',
    'VOUCHER-02-02', 'IN-02', 'OUT-02', 98000002
  ),
  (
    @teway_test_user_id, @teway_test_user_id, 980000299, 'TX_CASE_02_OBSOLETE', '待删除测试数据',
    0, '待删除', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-02', 'TX-DOC-02-OBSOLETE', 'TX-FACTORY', 980001, @teway_test_eid,
    'MAT-OBSOLETE', '待删除物料', 'BATCH-OBSOLETE', '1.000', 'OUT',
    'VOUCHER-02-OBSOLETE', '', 'OUT-02', 98000002
  );

CREATE TEMPORARY TABLE `teway_data_summary_scope_tmp` AS
SELECT
  `d`.`id`, `d`.`data_id`, `d`.`work_order_number`, `d`.`material_code`, `d`.`material_name`,
  `d`.`material_batch_no`, CAST(`d`.`total_quantity` AS DECIMAL(18, 3)) AS `quantity`,
  `d`.`create_by`, `d`.`eid`, `d`.`org_id`, `d`.`factory_area_code`
FROM `teway_data_summary` `d`
INNER JOIN `mid_iam_user` `u`
  ON `u`.`id` = `d`.`create_by`
WHERE `d`.`eid` = @teway_test_eid
  AND `d`.`data_id` BETWEEN 980000201 AND 980000202
  AND `d`.`business_type` = 'TX_CASE_02_DETAIL'
  AND `d`.`rec_status` = 1
  AND `d`.`response_status` = 0
  AND `u`.`rec_status` = 1
  AND `u`.`is_disabled` = 0;

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
WHERE `quantity` > 0
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
INNER JOIN `teway_data_summary_scope_tmp` `s`
  ON `s`.`id` = `d`.`id`
INNER JOIN `teway_data_summary_staging_tmp` `st`
  ON `st`.`work_order_number` = `s`.`work_order_number`
 AND `st`.`material_code` = `s`.`material_code`
INNER JOIN `teway_data_summary` `r`
  ON `r`.`eid` = `st`.`eid`
 AND `r`.`data_id` = 980000250
 AND `r`.`business_type` = 'TX_CASE_02_RESULT'
 AND `r`.`response_status` = 200
SET `d`.`response_status` = 200,
    `d`.`response_message` = 'CASE_02_DETAIL_COMMITTED',
    `d`.`response_time` = NOW(),
    `d`.`datasyn_third_status` = 2,
    `d`.`datasyn_third_msg` = '已汇总',
    `d`.`modify_by` = @teway_test_user_id,
    `d`.`modify_time` = NOW()
WHERE `d`.`rec_status` = 1
  AND `d`.`response_status` = 0;

DELETE FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000299
  AND `business_type` = 'TX_CASE_02_OBSOLETE'
  AND `response_status` = 0;

COMMIT;

DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_staging_tmp`;

SELECT `data_id`, `business_type`, `response_status`, `total_quantity`, `response_message`
FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` BETWEEN 980000201 AND 980000299
ORDER BY `data_id`;

-- 3. 动态 SQL 故意引用不存在的字段，异常处理器会回滚全部 DML
DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_error_tmp`;
DROP PROCEDURE IF EXISTS `sp_teway_tx_case_03_rollback`;

DELIMITER $$
CREATE PROCEDURE `sp_teway_tx_case_03_rollback`(OUT `p_result` varchar(64))
BEGIN
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_error_tmp`;
    SET `p_result` = 'EXPECTED_ERROR_ROLLED_BACK';
  END;

  DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_error_tmp`;
  START TRANSACTION;

  INSERT INTO `teway_data_summary` (
    `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
    `response_status`, `response_message`, `request_system`, `response_system`,
    `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
    `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
    `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
  )
  VALUES (
    @teway_test_user_id, @teway_test_user_id, 980000301, 'TX_CASE_03', '应回滚的数据',
    0, '执行中', 'TX_TEST_CLIENT', 'TEWAY',
    'TX-WO-03', 'TX-DOC-03', 'TX-FACTORY', 980001, @teway_test_eid,
    'MAT-CASE-03', '事务测试物料三', 'BATCH-03', '3.000', 'IN',
    'VOUCHER-03', 'IN-03', 'OUT-03', 98000003
  );

  UPDATE `teway_data_summary`
  SET `response_status` = 202,
      `response_message` = '此修改必须回滚',
      `modify_by` = @teway_test_user_id,
      `modify_time` = NOW()
  WHERE `eid` = @teway_test_eid
    AND `data_id` = 980000301
    AND `response_status` = 0;

  CREATE TEMPORARY TABLE `teway_data_summary_error_tmp` AS
  SELECT `id`, `data_id`
  FROM `teway_data_summary`
  WHERE `eid` = @teway_test_eid
    AND `data_id` = 980000301
    AND `response_status` = 202;

  SET @teway_case_03_bad_sql :=
    'UPDATE `teway_data_summary` SET `not_exists_column` = 1 WHERE `data_id` = 980000301';
  PREPARE teway_case_03_bad_stmt FROM @teway_case_03_bad_sql;
  EXECUTE teway_case_03_bad_stmt;
  DEALLOCATE PREPARE teway_case_03_bad_stmt;

  COMMIT;
  DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_error_tmp`;
  SET `p_result` = 'UNEXPECTED_SUCCESS';
END$$
DELIMITER ;

CALL `sp_teway_tx_case_03_rollback`(@teway_case_03_result);

SELECT @teway_case_03_result AS `case_03_result`;

SELECT COUNT(*) AS `rolled_back_row_count`
FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000301
  AND `business_type` = 'TX_CASE_03';

DROP TEMPORARY TABLE IF EXISTS `teway_data_summary_error_tmp`;
DROP PROCEDURE IF EXISTS `sp_teway_tx_case_03_rollback`;

-- 4. 保存点：局部回滚后保留指定数据并提交
START TRANSACTION;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES (
  @teway_test_user_id, @teway_test_user_id, 980000401, 'TX_CASE_04', '保存点保留数据',
  0, '已创建', 'TX_TEST_CLIENT', 'TEWAY',
  'TX-WO-04', 'TX-DOC-04', 'TX-FACTORY', 980001, @teway_test_eid,
  'MAT-CASE-04', '事务测试物料四', 'BATCH-04', '4.000', 'IN',
  'VOUCHER-04', 'IN-04', 'OUT-04', 98000004
);

SAVEPOINT `teway_case_04_before_trial`;

UPDATE `teway_data_summary`
SET `response_status` = 202,
    `response_message` = '该修改将被局部回滚',
    `modify_by` = @teway_test_user_id,
    `modify_time` = NOW()
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000401
  AND `response_status` = 0;

INSERT INTO `teway_data_summary` (
  `create_by`, `modify_by`, `data_id`, `business_type`, `business_name`,
  `response_status`, `response_message`, `request_system`, `response_system`,
  `work_order_number`, `document_code`, `factory_area_code`, `org_id`, `eid`,
  `material_code`, `material_name`, `material_batch_no`, `total_quantity`, `handle_type`,
  `material_voucher`, `entry_store_code`, `out_store_code`, `task_record_id`
)
VALUES (
  @teway_test_user_id, @teway_test_user_id, 980000402, 'TX_CASE_04_TRIAL', '应局部回滚的数据',
  0, '临时数据', 'TX_TEST_CLIENT', 'TEWAY',
  'TX-WO-04', 'TX-DOC-04-TRIAL', 'TX-FACTORY', 980001, @teway_test_eid,
  'MAT-CASE-04-TRIAL', '临时物料', 'BATCH-04-TRIAL', '1.000', 'OUT',
  'VOUCHER-04-TRIAL', '', 'OUT-04', 98000004
);

DELETE FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000401
  AND `business_type` = 'TX_CASE_04';

ROLLBACK TO SAVEPOINT `teway_case_04_before_trial`;

UPDATE `teway_data_summary`
SET `response_status` = 206,
    `response_message` = 'CASE_04_SAVEPOINT_COMMITTED',
    `modify_by` = @teway_test_user_id,
    `modify_time` = NOW()
WHERE `eid` = @teway_test_eid
  AND `data_id` = 980000401
  AND `response_status` = 0;

COMMIT;

SELECT `data_id`, `business_type`, `response_status`, `response_message`
FROM `teway_data_summary`
WHERE `eid` = @teway_test_eid
  AND `data_id` BETWEEN 980000401 AND 980000402
ORDER BY `data_id`;
