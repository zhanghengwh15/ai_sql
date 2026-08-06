-- =====================================================================
-- 业务名称：燕塘生产工单默认仓库与门店编码计算
-- 主表：    yt_mid_produce_work_order
-- 关联表：  yt_material_formal
-- 触发方式：定时计算任务
-- 数据库：  MySQL 8
-- 说明：    仅处理 calculate_status = 1 的最近 24 小时数据；
--          成功计算门店编码的记录才更新 calculate_status 为 2。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 清理当前连接中可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_mid_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_mid_produce_work_order_success_tmp`;

-- ---------------------------------------------------------------------
-- 1. 锁定本批待计算工单范围
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_mid_produce_work_order_scope_tmp`
ENGINE = InnoDB
AS
SELECT
    `id`
FROM `yt_mid_produce_work_order`
WHERE `calculate_status` = 1
    AND `modify_time` >= NOW() - INTERVAL 24 HOUR
ORDER BY `id`
LIMIT 500;

ALTER TABLE `yt_mid_produce_work_order_scope_tmp`
    ADD PRIMARY KEY (`id`);

/* 验证 SQL-1：确认本批锁定范围
SELECT COUNT(*) AS `locked_count`
FROM `yt_mid_produce_work_order_scope_tmp`;

SELECT `work_order`.`id`, `work_order`.`material_code`,
       `work_order`.`trace_number`, `work_order`.`moren_warehouse_id`,
       `work_order`.`store_code`, `work_order`.`calculate_status`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
ORDER BY `work_order`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 2. 按物料编码补全默认仓库；物料正式表未命中时保留原默认仓库
-- ---------------------------------------------------------------------
UPDATE `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
INNER JOIN `yt_material_formal` AS `material`
    ON `material`.`materialcode` = `work_order`.`material_code`
SET `work_order`.`moren_warehouse_id` = `material`.`moren_warehouse_id`,
    `work_order`.`modify_time` = NOW()
WHERE `work_order`.`calculate_status` = 1;

/* 验证 SQL-2：核对默认仓库补全与物料未命中记录
SELECT
    `work_order`.`moren_warehouse_id`,
    COUNT(*) AS `record_count`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
GROUP BY `work_order`.`moren_warehouse_id`;

SELECT `work_order`.`id`, `work_order`.`material_code`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
LEFT JOIN `yt_material_formal` AS `material`
    ON `material`.`materialcode` = `work_order`.`material_code`
WHERE `material`.`materialcode` IS NULL
ORDER BY `work_order`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 3. 按优先级计算门店编码
--    1) trace_number 非空：870kw
--    2) 默认仓库为 tbYAAAy7mTy76fiu：821kw
--    3) 其他：820kw
-- ---------------------------------------------------------------------
UPDATE `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
SET `work_order`.`store_code` = CASE
        WHEN `work_order`.`trace_number` IS NOT NULL THEN '870kw'
        WHEN `work_order`.`moren_warehouse_id` = 'tbYAAAy7mTy76fiu' THEN '821kw'
        ELSE '820kw'
    END,
    `work_order`.`modify_time` = NOW()
WHERE `work_order`.`calculate_status` = 1;

/* 验证 SQL-3：检查门店编码优先级计算结果
SELECT
    `work_order`.`store_code`,
    COUNT(*) AS `record_count`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
GROUP BY `work_order`.`store_code`;

SELECT `work_order`.`id`, `work_order`.`trace_number`,
       `work_order`.`moren_warehouse_id`, `work_order`.`store_code`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
ORDER BY `work_order`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 4. 成功子集：只保留门店编码已与当前规则一致的记录
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_mid_produce_work_order_success_tmp`
ENGINE = InnoDB
AS
SELECT
    `work_order`.`id`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
WHERE `work_order`.`calculate_status` = 1
    AND `work_order`.`modify_time` >= NOW() - INTERVAL 24 HOUR
    AND `work_order`.`store_code` = CASE
        WHEN `work_order`.`trace_number` IS NOT NULL THEN '870kw'
        WHEN `work_order`.`moren_warehouse_id` = 'tbYAAAy7mTy76fiu' THEN '821kw'
        ELSE '820kw'
    END
ORDER BY `work_order`.`id`
LIMIT 5000;

ALTER TABLE `yt_mid_produce_work_order_success_tmp`
    ADD PRIMARY KEY (`id`);

/* 验证 SQL-4：对比锁定范围和成功子集
SELECT
    (SELECT COUNT(*) FROM `yt_mid_produce_work_order_scope_tmp`) AS `locked_count`,
    (SELECT COUNT(*) FROM `yt_mid_produce_work_order_success_tmp`) AS `success_count`;

SELECT `scope`.`id` AS `unfinished_id`
FROM `yt_mid_produce_work_order_scope_tmp` AS `scope`
LEFT JOIN `yt_mid_produce_work_order_success_tmp` AS `success_scope`
    ON `success_scope`.`id` = `scope`.`id`
WHERE `success_scope`.`id` IS NULL
ORDER BY `scope`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 5. 仅回写成功子集为已完成，避免未成功处理的数据被误标记
-- ---------------------------------------------------------------------
UPDATE `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_success_tmp` AS `success_scope`
    ON `success_scope`.`id` = `work_order`.`id`
SET `work_order`.`calculate_status` = 2,
    `work_order`.`modify_time` = NOW()
WHERE `work_order`.`calculate_status` = 1;

/* 验证 SQL-5：确认成功子集已更新为完成态
SELECT
    `work_order`.`calculate_status`,
    COUNT(*) AS `record_count`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_scope_tmp` AS `scope`
    ON `scope`.`id` = `work_order`.`id`
GROUP BY `work_order`.`calculate_status`;

SELECT `work_order`.`id`, `work_order`.`calculate_status`,
       `work_order`.`store_code`
FROM `yt_mid_produce_work_order` AS `work_order`
INNER JOIN `yt_mid_produce_work_order_success_tmp` AS `success_scope`
    ON `success_scope`.`id` = `work_order`.`id`
WHERE `work_order`.`calculate_status` <> 2
ORDER BY `work_order`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 6. 清理临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_mid_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_mid_produce_work_order_success_tmp`;
