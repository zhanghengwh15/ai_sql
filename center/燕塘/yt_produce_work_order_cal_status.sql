-- =====================================================================
-- 业务名称：生产工单状态变化计算与 cal_status 回写
-- 主表：    yt_produce_work_order
-- 触发方式：定时任务 / 手动
-- 日期：    2026-08-20
-- 计算规则：
--   1. 在同一 eid + doc_no 内，按 dop_modify_time、id 排序；
--   2. 当前记录相对紧邻上一条记录的 dop_modify_time 发生变化时：
--      - status 发生变化：cal_status = 1；
--      - status 保持一致：cal_status = 2；
--   3. 同一 eid + doc_no 只有一条有效记录时：
--      - status = 0：cal_status = 2；
--      - status <> 0 或 status IS NULL：cal_status = 1；
--   4. 存在上一条记录但 dop_modify_time 未变化时，不回写 cal_status。
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 清理当前连接中可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_staging_tmp`;

-- ---------------------------------------------------------------------
-- 1. 范围表：锁定每个 eid + doc_no 当前最新且待计算的记录
--    - cal_status = 0：幂等条件
--    - modify_time：只处理最近 24 小时发生变化的数据
--    - NOT EXISTS：排除同一单据下比当前记录更新的有效记录
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_produce_work_order_scope_tmp` AS
SELECT
    `current_order`.`id`,
    `current_order`.`eid`,
    `current_order`.`doc_no`,
    `current_order`.`status`,
    `current_order`.`dop_modify_time`,
    `current_order`.`modify_time`
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
        AND `newer_order`.`doc_no` = `current_order`.`doc_no`
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

/* 验证 SQL-1：确认本次锁定范围
SELECT COUNT(*) AS `locked_cnt`
FROM `yt_produce_work_order_scope_tmp`;

SELECT
    `id`,
    `eid`,
    `doc_no`,
    `status`,
    `dop_modify_time`,
    `modify_time`
FROM `yt_produce_work_order_scope_tmp`
ORDER BY `id`
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 2. Staging：计算当前记录与紧邻上一条历史记录的差异
--    窗口函数必须先在派生表中计算，再由外层 WHERE 过滤结果；
--    不能在 WINDOW 子句后使用 HAVING 过滤窗口函数别名。
--    若没有上一条记录，则按当前 status 直接计算 cal_status。
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `yt_produce_work_order_staging_tmp` AS
SELECT
    `history_order`.`id`,
    `history_order`.`eid`,
    `history_order`.`doc_no`,
    `history_order`.`status`,
    `history_order`.`dop_modify_time`,
    `history_order`.`prev_id`,
    `history_order`.`prev_status`,
    `history_order`.`prev_dop_modify_time`,
    CASE
        WHEN `history_order`.`prev_id` IS NULL
             AND (`history_order`.`status` <=> 0) THEN 2
        WHEN `history_order`.`prev_id` IS NULL THEN 1
        WHEN NOT (
            `history_order`.`prev_status` <=> `history_order`.`status`
        ) THEN 1
        ELSE 2
    END AS `new_cal_status`
FROM (
    SELECT
        `work_order`.`id`,
        `work_order`.`eid`,
        `work_order`.`doc_no`,
        `work_order`.`status`,
        `work_order`.`dop_modify_time`,
        `scope_order`.`id` AS `scope_id`,
        `scope_order`.`modify_time` AS `scope_modify_time`,
        LAG(`work_order`.`id`) OVER (
            PARTITION BY `work_order`.`eid`, `work_order`.`doc_no`
            ORDER BY `work_order`.`dop_modify_time` ASC,
                     `work_order`.`id` ASC
        ) AS `prev_id`,
        LAG(`work_order`.`status`) OVER (
            PARTITION BY `work_order`.`eid`, `work_order`.`doc_no`
            ORDER BY `work_order`.`dop_modify_time` ASC,
                     `work_order`.`id` ASC
        ) AS `prev_status`,
        LAG(`work_order`.`dop_modify_time`) OVER (
            PARTITION BY `work_order`.`eid`, `work_order`.`doc_no`
            ORDER BY `work_order`.`dop_modify_time` ASC,
                     `work_order`.`id` ASC
        ) AS `prev_dop_modify_time`
    FROM `yt_produce_work_order` AS `work_order`
    INNER JOIN `yt_produce_work_order_scope_tmp` AS `scope_order`
        ON `scope_order`.`eid` = `work_order`.`eid`
       AND `scope_order`.`doc_no` = `work_order`.`doc_no`
    WHERE `work_order`.`rec_status` = 1
) AS `history_order`
WHERE `history_order`.`id` = `history_order`.`scope_id`
  AND `history_order`.`scope_modify_time` >= NOW() - INTERVAL 24 HOUR
  AND (
      `history_order`.`prev_id` IS NULL
      OR NOT (
          `history_order`.`prev_dop_modify_time`
              <=> `history_order`.`dop_modify_time`
      )
  )
ORDER BY `history_order`.`id`
LIMIT 1000;

/* 验证 SQL-2：检查单条记录规则及相邻历史记录对比结果
SELECT
    `id`,
    `eid`,
    `doc_no`,
    `prev_id`,
    `prev_status`,
    `status`,
    `prev_dop_modify_time`,
    `dop_modify_time`,
    `new_cal_status`
FROM `yt_produce_work_order_staging_tmp`
ORDER BY `id`
LIMIT 20;

SELECT
    `status`,
    `new_cal_status`,
    COUNT(*) AS `single_doc_cnt`
FROM `yt_produce_work_order_staging_tmp`
WHERE `prev_id` IS NULL
GROUP BY `status`, `new_cal_status`
ORDER BY `status`, `new_cal_status`;
*/

/* 验证 SQL-3：范围与成功子集数量、计算结果分布
SELECT
    (SELECT COUNT(*)
     FROM `yt_produce_work_order_scope_tmp`) AS `locked_cnt`,
    (SELECT COUNT(*)
     FROM `yt_produce_work_order_staging_tmp`) AS `passed_cnt`;

SELECT
    `new_cal_status`,
    COUNT(*) AS `cnt`
FROM `yt_produce_work_order_staging_tmp`
GROUP BY `new_cal_status`
ORDER BY `new_cal_status`;
*/

/* 验证 SQL-4：回写前预览新旧 cal_status
SELECT
    `work_order`.`id`,
    `work_order`.`eid`,
    `work_order`.`doc_no`,
    `work_order`.`cal_status` AS `old_cal_status`,
    `staging_order`.`new_cal_status`,
    `staging_order`.`prev_status`,
    `staging_order`.`status`,
    `staging_order`.`prev_dop_modify_time`,
    `staging_order`.`dop_modify_time`
FROM `yt_produce_work_order_staging_tmp` AS `staging_order`
INNER JOIN `yt_produce_work_order` AS `work_order`
    ON `work_order`.`id` = `staging_order`.`id`
WHERE `work_order`.`cal_status` = 0
  AND `work_order`.`rec_status` = 1
ORDER BY `work_order`.`id`
LIMIT 100;
*/

-- ---------------------------------------------------------------------
-- 3. 状态回写：只更新进入 Staging 的成功子集
--    再次校验 cal_status = 0，降低并发任务重复处理风险。
-- ---------------------------------------------------------------------
UPDATE `yt_produce_work_order` AS `work_order`
INNER JOIN `yt_produce_work_order_staging_tmp` AS `staging_order`
    ON `staging_order`.`id` = `work_order`.`id`
SET `work_order`.`cal_status` = `staging_order`.`new_cal_status`,
    `work_order`.`modify_time` = NOW(),
    `work_order`.`modify_by` = 0
WHERE `work_order`.`cal_status` = 0
  AND `work_order`.`rec_status` = 1;

/* 验证 SQL-5：本批状态分布与回写遗漏检查
SELECT
    `work_order`.`cal_status`,
    COUNT(*) AS `cnt`
FROM `yt_produce_work_order_scope_tmp` AS `scope_order`
INNER JOIN `yt_produce_work_order` AS `work_order`
    ON `work_order`.`id` = `scope_order`.`id`
GROUP BY `work_order`.`cal_status`
ORDER BY `work_order`.`cal_status`;

SELECT
    `work_order`.`id`,
    `work_order`.`eid`,
    `work_order`.`doc_no`,
    `work_order`.`cal_status`,
    `staging_order`.`new_cal_status`
FROM `yt_produce_work_order_staging_tmp` AS `staging_order`
INNER JOIN `yt_produce_work_order` AS `work_order`
    ON `work_order`.`id` = `staging_order`.`id`
WHERE `work_order`.`cal_status` = 0;
*/

-- ---------------------------------------------------------------------
-- 4. 收尾：释放当前连接中的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `yt_produce_work_order_staging_tmp`;
