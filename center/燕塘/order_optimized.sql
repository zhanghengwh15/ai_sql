DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_staging_tmp`;

CREATE TEMPORARY TABLE `yt_produce_work_order_scope_tmp` AS
SELECT
    `current_order`.`id`,
    `current_order`.`eid`
FROM `yt_produce_work_order` AS `current_order`
WHERE `current_order`.`rec_status` = 1
  AND `current_order`.`cal_status` = 0
  AND `current_order`.`eid` <> ''
  AND `current_order`.`doc_no` IS NOT NULL
  AND `current_order`.`doc_no` <> ''
  AND `current_order`.`modify_time` >= NOW() - INTERVAL 24 HOUR
  AND NOT EXISTS (
      SELECT 1
      FROM `yt_produce_work_order` AS `newer_order`
      WHERE `newer_order`.`rec_status` = 1
        AND `newer_order`.`eid` = `current_order`.`eid`
        AND (
            `newer_order`.`dop_modify_time` > `current_order`.`dop_modify_time`
            OR (
                `newer_order`.`dop_modify_time` <=> `current_order`.`dop_modify_time`
                AND `newer_order`.`id` > `current_order`.`id`
            )
            OR (
                `current_order`.`dop_modify_time` IS NULL
                AND `newer_order`.`dop_modify_time` IS NOT NULL
            )
        )
  )
ORDER BY `current_order`.`id`
LIMIT 1000;

ALTER TABLE `yt_produce_work_order_scope_tmp`
    ADD PRIMARY KEY (`id`),
    ADD UNIQUE INDEX `idx_scope_eid` (`eid`);

CREATE TEMPORARY TABLE `yt_produce_work_order_staging_tmp` AS
SELECT
    `history_order`.`id`,
    CASE
        WHEN `history_order`.`prev_id` IS NULL
             AND (`history_order`.`status` <=> 0) THEN 2
        WHEN `history_order`.`prev_id` IS NULL THEN 1
        WHEN (`history_order`.`prev_doc_no` <=> `history_order`.`doc_no`)
         AND (`history_order`.`prev_status` <=> `history_order`.`status`) THEN 2
        ELSE 1
    END AS `new_cal_status`
FROM (
    SELECT
        `work_order`.`id`,
        `work_order`.`doc_no`,
        `work_order`.`status`,
        `scope_order`.`id` AS `scope_id`,
        LAG(`work_order`.`id`) OVER (
            PARTITION BY `work_order`.`eid`
            ORDER BY `work_order`.`dop_modify_time`, `work_order`.`id`
        ) AS `prev_id`,
        LAG(`work_order`.`doc_no`) OVER (
            PARTITION BY `work_order`.`eid`
            ORDER BY `work_order`.`dop_modify_time`, `work_order`.`id`
        ) AS `prev_doc_no`,
        LAG(`work_order`.`status`) OVER (
            PARTITION BY `work_order`.`eid`
            ORDER BY `work_order`.`dop_modify_time`, `work_order`.`id`
        ) AS `prev_status`
    FROM `yt_produce_work_order` AS `work_order`
    INNER JOIN `yt_produce_work_order_scope_tmp` AS `scope_order`
        ON `scope_order`.`eid` = `work_order`.`eid`
    WHERE `work_order`.`rec_status` = 1
) AS `history_order`
WHERE `history_order`.`id` = `history_order`.`scope_id`;

ALTER TABLE `yt_produce_work_order_staging_tmp`
    ADD PRIMARY KEY (`id`);

UPDATE `yt_produce_work_order` AS `work_order`
INNER JOIN `yt_produce_work_order_staging_tmp` AS `staging_order`
    ON `staging_order`.`id` = `work_order`.`id`
SET `work_order`.`cal_status` = `staging_order`.`new_cal_status`,
    `work_order`.`modify_time` = NOW(),
    `work_order`.`modify_by` = 0
WHERE `work_order`.`cal_status` = 0
  AND `work_order`.`rec_status` = 1;

DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_staging_tmp`;
