-- 0. 燕塘备件领料申请单计算任务（MySQL 8）；清理临时表。
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_detail_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_request_tmp`;

-- 1. 固定本批待计算记录，保留原有时间和批次范围。
CREATE TEMPORARY TABLE `yt_dop_spare_parts_scope_tmp`
ENGINE = InnoDB
AS
SELECT
    `id`,
    `eid`,
    `docket_code`,
    `factory_area_name`,
    `modify_time` AS `source_modify_time`,
    `detail_field`
FROM `yt_dop_spare_parts`
WHERE `rec_status` = 1
    AND `calc_sync_status` = 1
    AND `request` IS NULL
    AND `detail_field` IS NOT NULL
    AND JSON_TYPE(`detail_field`) = 'ARRAY'
    AND JSON_LENGTH(`detail_field`) > 0
    AND `modify_time` >= NOW() - INTERVAL 48 HOUR
ORDER BY `id`
LIMIT 5000;

ALTER TABLE `yt_dop_spare_parts_scope_tmp`
    ADD PRIMARY KEY (`id`);

-- 2. 使用 JSON_TABLE 展开明细，保持原有 99 条及 500000 行限制。
CREATE TEMPORARY TABLE `yt_dop_spare_parts_detail_tmp`
ENGINE = InnoDB
AS
SELECT
    `scope`.`id`,
    `detail_item`.`line_no` AS `line_no`,
    NULLIF(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                `scope`.`detail_field`,
                CONCAT('$[', `detail_item`.`line_no` - 1, '].materialCode')
            )
        ),
        'null'
    ) AS `material_code`,
    NULLIF(
        JSON_UNQUOTE(
            JSON_EXTRACT(
                `scope`.`detail_field`,
                CONCAT('$[', `detail_item`.`line_no` - 1, '].totalWarehousingCount')
            )
        ),
        'null'
    ) AS `qty_ordered`
FROM `yt_dop_spare_parts_scope_tmp` AS `scope`
JOIN JSON_TABLE(
    `scope`.`detail_field`, '$[*]'
    COLUMNS (`line_no` FOR ORDINALITY)
) AS `detail_item` ON `detail_item`.`line_no` <= 99
ORDER BY `scope`.`id`, `detail_item`.`line_no`
LIMIT 500000;

ALTER TABLE `yt_dop_spare_parts_detail_tmp`
    ADD PRIMARY KEY (`id`, `line_no`);

-- 3. 按明细顺序生成通过完整性校验的 request 和成本中心。
CREATE TEMPORARY TABLE `yt_dop_spare_parts_request_tmp`
ENGINE = InnoDB
AS
SELECT
    `aggregated`.`id`,
    `aggregated`.`source_modify_time`,
    `aggregated`.`detail_count`,
    `aggregated`.`cost_center`,
    CAST(
        CONCAT('[', `aggregated`.`request_items`, ']')
        AS JSON
    ) AS `request`
FROM (
    SELECT
        `scope`.`id`,
        MIN(`scope`.`source_modify_time`) AS `source_modify_time`,
        MIN(JSON_LENGTH(`scope`.`detail_field`)) AS `detail_count`,
        MIN(CASE
            WHEN `scope`.`factory_area_name` LIKE '%/常温车间/%' THEN '1101310202'
            WHEN `scope`.`factory_area_name` LIKE '%/低温车间/%' THEN '1101310101'
            WHEN `scope`.`factory_area_name` LIKE '%/中控车间/%' THEN '1101310301'
            ELSE ''
        END) AS `cost_center`,
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
    INNER JOIN `yt_dop_spare_parts_detail_tmp` AS `detail`
        ON `detail`.`id` = `scope`.`id`
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
    AND OCTET_LENGTH(`aggregated`.`request_items`)
        < CAST(@@SESSION.group_concat_max_len AS UNSIGNED)
    AND JSON_VALID(CONCAT('[', `aggregated`.`request_items`, ']')) = 1
ORDER BY `aggregated`.`id`
LIMIT 5000;

ALTER TABLE `yt_dop_spare_parts_request_tmp`
    ADD PRIMARY KEY (`id`);

-- 4. 仅回写通过校验且本批期间未被其他任务修改的记录。
UPDATE `yt_dop_spare_parts` AS `spare_parts`
INNER JOIN `yt_dop_spare_parts_request_tmp` AS `request_tmp`
    ON `request_tmp`.`id` = `spare_parts`.`id`
    AND `request_tmp`.`source_modify_time` = `spare_parts`.`modify_time`
SET `spare_parts`.`request` = `request_tmp`.`request`,
    `spare_parts`.`cost_center` = `request_tmp`.`cost_center`,
    `spare_parts`.`calc_sync_status` = 2,
    `spare_parts`.`modify_by` = 0,
    `spare_parts`.`modify_time` = NOW()
WHERE `spare_parts`.`rec_status` = 1
    AND `spare_parts`.`calc_sync_status` = 1
    AND `spare_parts`.`request` IS NULL;

-- 5. 清理临时表。
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_detail_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_dop_spare_parts_request_tmp`;
