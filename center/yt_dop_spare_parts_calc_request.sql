-- =====================================================================
-- 业务名称：燕塘备件领料申请单 request 计算任务
-- 主表：    yt_dop_spare_parts
-- 触发方式：定时计算任务
-- 数据库：  MySQL 8.0.4+
-- 说明：    将 detail_field 数组转换为 request 数组：
--          materialCode -> sku
--          totalWarehousingCount -> qtyOrdered
--          数组自然序号 -> lineNo
-- 参数：    {{eid}} 为企业 ID，执行前必须替换
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 清理当前连接中可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_request_tmp`;

-- ---------------------------------------------------------------------
-- 1. 锁定本批待计算记录
--    request IS NULL 是幂等条件，成功写入后不会被下一批重复处理
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_dop_spare_parts_scope_tmp`
ENGINE = InnoDB
AS
SELECT
    `id`,
    `eid`,
    `docket_code`,
    `modify_time` AS `source_modify_time`,
    `detail_field`
FROM `yt_dop_spare_parts`
WHERE `eid` = '{{eid}}'
    AND `rec_status` = 1
    AND `calc_sync_status` = 1
    AND `request` IS NULL
    AND `detail_field` IS NOT NULL
    AND JSON_TYPE(`detail_field`) = 'ARRAY'
    AND JSON_LENGTH(`detail_field`) > 0
    AND `modify_time` >= NOW() - INTERVAL 24 HOUR
ORDER BY `id`
LIMIT 5000;

ALTER TABLE `yt_dop_spare_parts_scope_tmp`
    ADD PRIMARY KEY (`id`);

/* 验证 SQL-1：确认本批锁定范围
SELECT COUNT(*) AS `locked_count`
FROM `yt_dop_spare_parts_scope_tmp`;

SELECT
    `id`,
    `eid`,
    `docket_code`,
    `source_modify_time`,
    JSON_LENGTH(`detail_field`) AS `detail_count`
FROM `yt_dop_spare_parts_scope_tmp`
ORDER BY `id`
LIMIT 20;
*/

/* 验证 SQL-2：检查 detail_field 展开与字段映射
SELECT
    `scope`.`id`,
    `detail`.`line_no`,
    `detail`.`material_code` AS `sku`,
    `detail`.`qty_ordered`
FROM `yt_dop_spare_parts_scope_tmp` AS `scope`
CROSS JOIN JSON_TABLE(
    `scope`.`detail_field`,
    '$[*]' COLUMNS (
        `line_no` FOR ORDINALITY,
        `material_code` VARCHAR(100) PATH '$.materialCode'
            NULL ON EMPTY NULL ON ERROR,
        `qty_ordered` VARCHAR(100) PATH '$.totalWarehousingCount'
            NULL ON EMPTY NULL ON ERROR
    )
) AS `detail`
ORDER BY `scope`.`id`, `detail`.`line_no`
LIMIT 50;
*/

-- ---------------------------------------------------------------------
-- 2. 生成通过完整性校验的 request 成功子集
--    GROUP_CONCAT 按 line_no 排序，确保数组顺序与原明细一致
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_dop_spare_parts_request_tmp`
ENGINE = InnoDB
AS
SELECT
    `aggregated`.`id`,
    `aggregated`.`source_modify_time`,
    `aggregated`.`detail_count`,
    CAST(
        CONCAT('[', `aggregated`.`request_items`, ']')
        AS JSON
    ) AS `request`
FROM (
    SELECT
        `scope`.`id`,
        MIN(`scope`.`source_modify_time`) AS `source_modify_time`,
        MIN(JSON_LENGTH(`scope`.`detail_field`)) AS `detail_count`,
        GROUP_CONCAT(
            JSON_OBJECT(
                'qtyOrdered', `detail`.`qty_ordered`,
                'lineNo', CAST(`detail`.`line_no` AS CHAR),
                'sku', `detail`.`material_code`
            )
            ORDER BY `detail`.`line_no`
            SEPARATOR ','
        ) AS `request_items`
    FROM `yt_dop_spare_parts_scope_tmp` AS `scope`
    CROSS JOIN JSON_TABLE(
        `scope`.`detail_field`,
        '$[*]' COLUMNS (
            `line_no` FOR ORDINALITY,
            `material_code` VARCHAR(100) PATH '$.materialCode'
                NULL ON EMPTY NULL ON ERROR,
            `qty_ordered` VARCHAR(100) PATH '$.totalWarehousingCount'
                NULL ON EMPTY NULL ON ERROR
        )
    ) AS `detail`
    GROUP BY `scope`.`id`
    HAVING COUNT(*) = MIN(JSON_LENGTH(`scope`.`detail_field`))
        AND SUM(
            CASE
                WHEN `detail`.`material_code` IS NULL
                    OR `detail`.`material_code` = ''
                    OR `detail`.`qty_ordered` IS NULL
                    OR `detail`.`qty_ordered` = ''
                THEN 1
                ELSE 0
            END
        ) = 0
) AS `aggregated`
WHERE `aggregated`.`request_items` IS NOT NULL
    AND OCTET_LENGTH(`aggregated`.`request_items`) < @@SESSION.group_concat_max_len
    AND JSON_VALID(CONCAT('[', `aggregated`.`request_items`, ']')) = 1
ORDER BY `aggregated`.`id`
LIMIT 5000;

ALTER TABLE `yt_dop_spare_parts_request_tmp`
    ADD PRIMARY KEY (`id`);

/* 验证 SQL-3：对比锁定范围与成功子集
SELECT
    (SELECT COUNT(*) FROM `yt_dop_spare_parts_scope_tmp`) AS `locked_count`,
    (SELECT COUNT(*) FROM `yt_dop_spare_parts_request_tmp`) AS `passed_count`;

SELECT
    `scope`.`id`,
    `scope`.`docket_code`,
    JSON_LENGTH(`scope`.`detail_field`) AS `source_detail_count`
FROM `yt_dop_spare_parts_scope_tmp` AS `scope`
LEFT JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `scope`.`id`
WHERE `request_tmp`.`id` IS NULL
ORDER BY `scope`.`id`
LIMIT 20;
*/

/* 验证 SQL-4：写入前核对 request 结构与明细数量
SELECT
    `spare_parts`.`id`,
    `spare_parts`.`docket_code`,
    `request_tmp`.`detail_count`,
    JSON_LENGTH(`request_tmp`.`request`) AS `request_count`,
    `request_tmp`.`request`
FROM `yt_dop_spare_parts` AS `spare_parts`
INNER JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `spare_parts`.`id`
    AND `request_tmp`.`source_modify_time` = `spare_parts`.`modify_time`
WHERE `spare_parts`.`eid` = '{{eid}}'
    AND `spare_parts`.`rec_status` = 1
    AND `spare_parts`.`calc_sync_status` = 1
    AND `spare_parts`.`request` IS NULL
ORDER BY `spare_parts`.`id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 3. 仅回写成功生成 request 且本批期间未被其他任务修改的记录
-- ---------------------------------------------------------------------
UPDATE `yt_dop_spare_parts` AS `spare_parts`
INNER JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `spare_parts`.`id`
    AND `request_tmp`.`source_modify_time` = `spare_parts`.`modify_time`
SET `spare_parts`.`request` = `request_tmp`.`request`,
    `spare_parts`.`modify_by` = 0,
    `spare_parts`.`modify_time` = NOW()
WHERE `spare_parts`.`eid` = '{{eid}}'
    AND `spare_parts`.`rec_status` = 1
    AND `spare_parts`.`calc_sync_status` = 1
    AND `spare_parts`.`request` IS NULL;

/* 验证 SQL-5：回写结果与未成功记录检查
SELECT
    `spare_parts`.`id`,
    `spare_parts`.`docket_code`,
    JSON_LENGTH(`spare_parts`.`detail_field`) AS `detail_count`,
    JSON_LENGTH(`spare_parts`.`request`) AS `request_count`,
    `spare_parts`.`request`
FROM `yt_dop_spare_parts` AS `spare_parts`
INNER JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `spare_parts`.`id`
WHERE `spare_parts`.`eid` = '{{eid}}'
ORDER BY `spare_parts`.`id`
LIMIT 20;

SELECT
    `scope`.`id`,
    `scope`.`docket_code`,
    CASE
        WHEN `request_tmp`.`id` IS NULL THEN 'DETAIL_VALIDATION_FAILED'
        WHEN `spare_parts`.`request` IS NULL THEN 'SOURCE_CHANGED_OR_UPDATE_SKIPPED'
        ELSE 'SUCCESS'
    END AS `result_status`
FROM `yt_dop_spare_parts_scope_tmp` AS `scope`
LEFT JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `scope`.`id`
LEFT JOIN `yt_dop_spare_parts` AS `spare_parts`
    ON `spare_parts`.`id` = `scope`.`id`
WHERE `request_tmp`.`id` IS NULL
    OR `spare_parts`.`request` IS NULL
ORDER BY `scope`.`id`
LIMIT 50;
*/

-- ---------------------------------------------------------------------
-- 4. 清理临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_request_tmp`;
