-- 新建时执行建表；已有表直接执行下方计算任务。
CREATE TABLE `mwx_production_statistics` (
  `id` bigint NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `rec_status` tinyint NOT NULL DEFAULT 1 COMMENT '记录状态',
  `create_by` bigint NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_by` bigint NOT NULL DEFAULT 0 COMMENT '修改人ID',
  `task_record_id` bigint NULL DEFAULT 0 COMMENT '任务记录ID',
  `eid` varchar(64) NULL COMMENT '企业标识',
  `workline_code` varchar(64) NOT NULL COMMENT '美味鲜-产线编码',
  `workline_name` varchar(128) NOT NULL COMMENT '美味鲜-产线名称',
  `total_output` decimal(18, 3) NOT NULL DEFAULT 0.000 COMMENT '美味鲜-产线总产量',
  `detail` json NULL COMMENT '美味鲜-产线明细JSON',
  `factory_code` varchar(64) NULL COMMENT '工厂编码',
  `factory_name` varchar(64) NULL,
  `cal_status` tinyint NULL DEFAULT 1 COMMENT '计算状态：1-待处理，2-有效整点样本，3-未入选',
  `time_output` decimal(18, 3) NULL DEFAULT 0.00 COMMENT '小时产量；没有上一小时的有效样本时为 NULL',
  `hour_24num` datetime NULL DEFAULT NULL COMMENT '样本归属的整点（含日期）',
  PRIMARY KEY (`id`),
  KEY `idx_cal_status_rec_status_create_time` (`cal_status`, `rec_status`, `create_time`),
  KEY `idx_factory_line_hour_status` (`factory_code`, `workline_code`, `hour_24num`, `cal_status`, `rec_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='美味鲜-产线产量统计';

-- 清理本次任务可能残留的临时表。
DROP TEMPORARY TABLE IF EXISTS `mwx_production_statistics_scope_tmp`, `mwx_production_statistics_closest_tmp`,
    `mwx_production_statistics_winner_tmp`, `mwx_production_statistics_baseline_tmp`;

-- 按 create_time 归入最近整点（半点归下一个），整点过 30 分钟再结算。
CREATE TEMPORARY TABLE `mwx_production_statistics_scope_tmp` (
    PRIMARY KEY (`id`)
) ENGINE=InnoDB AS
SELECT sample.`id`, sample.`factory_code`, sample.`workline_code`,
       sample.`hour_24num`, ABS(TIMESTAMPDIFF(SECOND, sample.`hour_24num`, sample.`create_time`)) AS `distance_seconds`
FROM (
    SELECT src.`id`, src.`factory_code`, src.`workline_code`, src.`create_time`,
           CAST(DATE_FORMAT(src.`create_time` + INTERVAL 30 MINUTE, '%Y-%m-%d %H:00:00') AS DATETIME) AS `hour_24num`
    FROM `mwx_production_statistics` AS src
    WHERE src.`cal_status` = 1
      AND src.`rec_status` = 1
      AND src.`create_time` < CAST(DATE_FORMAT(NOW() - INTERVAL 30 MINUTE, '%Y-%m-%d %H:30:00') AS DATETIME)
) AS sample;

-- 同工厂、产线及整点取最小时间偏差；已结算的整点保留原样本。
CREATE TEMPORARY TABLE `mwx_production_statistics_closest_tmp` (
    KEY `idx_factory_line_hour` (`factory_code`, `workline_code`, `hour_24num`)
) ENGINE=InnoDB AS
SELECT candidate.`factory_code`, candidate.`workline_code`,
       candidate.`hour_24num`, MIN(candidate.`distance_seconds`) AS `distance_seconds`
FROM `mwx_production_statistics_scope_tmp` AS candidate
WHERE NOT EXISTS (
    SELECT 1
    FROM `mwx_production_statistics` AS finalized
    WHERE finalized.`factory_code` <=> candidate.`factory_code`
      AND finalized.`workline_code` = candidate.`workline_code`
      AND finalized.`hour_24num` = candidate.`hour_24num`
      AND finalized.`cal_status` = 2
      AND finalized.`rec_status` = 1
)
GROUP BY candidate.`factory_code`, candidate.`workline_code`, candidate.`hour_24num`;

-- 偏差相同时取最小 id，并查找恰好上一小时的历史有效样本。
CREATE TEMPORARY TABLE `mwx_production_statistics_winner_tmp` (
    PRIMARY KEY (`id`)
) ENGINE=InnoDB AS
SELECT winner.`id`, winner.`factory_code`, winner.`workline_code`,
       winner.`hour_24num`, current_sample.`total_output`, (
           SELECT history.`total_output`
           FROM `mwx_production_statistics` AS history
           WHERE history.`factory_code` <=> winner.`factory_code`
             AND history.`workline_code` = winner.`workline_code`
             AND history.`hour_24num` = winner.`hour_24num` - INTERVAL 1 HOUR
             AND (
                 history.`cal_status` = 2
                 OR (
                     history.`cal_status` = 3
                     AND history.`total_output` = 0
                     AND history.`hour_24num` = CAST(DATE(history.`hour_24num`) AS DATETIME)
                 )
             )
             AND history.`rec_status` = 1
           ORDER BY history.`id`
           LIMIT 1
       ) AS `historical_output`
FROM (
    SELECT MIN(candidate.`id`) AS `id`, candidate.`factory_code`, candidate.`workline_code`, candidate.`hour_24num`
    FROM `mwx_production_statistics_scope_tmp` AS candidate
    INNER JOIN `mwx_production_statistics_closest_tmp` AS closest
        ON closest.`factory_code` <=> candidate.`factory_code`
       AND closest.`workline_code` = candidate.`workline_code`
       AND closest.`hour_24num` = candidate.`hour_24num`
       AND closest.`distance_seconds` = candidate.`distance_seconds`
    GROUP BY candidate.`factory_code`, candidate.`workline_code`, candidate.`hour_24num`
) AS winner
INNER JOIN `mwx_production_statistics` AS current_sample ON current_sample.`id` = winner.`id`;

-- 将同批入选样本单独暂存为下一小时的基准，避免在回写语句中重复引用同一临时表。
CREATE TEMPORARY TABLE `mwx_production_statistics_baseline_tmp` (
    KEY `idx_factory_line_next_hour` (`factory_code`, `workline_code`, `next_hour`)
) ENGINE=InnoDB AS
SELECT `factory_code`, `workline_code`, `total_output`,
       `hour_24num` + INTERVAL 1 HOUR AS `next_hour`
FROM `mwx_production_statistics_winner_tmp`
WHERE `total_output` > 0
   OR `hour_24num` = CAST(DATE(`hour_24num`) AS DATETIME);

-- 有产量的入选样本置为 2，零产量样本保留整点但置为 3；本批未入选置为 3。
UPDATE `mwx_production_statistics` AS src
INNER JOIN `mwx_production_statistics_scope_tmp` AS candidate ON candidate.`id` = src.`id`
LEFT JOIN `mwx_production_statistics_winner_tmp` AS winner ON winner.`id` = src.`id`
LEFT JOIN `mwx_production_statistics_baseline_tmp` AS baseline
    ON baseline.`factory_code` <=> winner.`factory_code`
   AND baseline.`workline_code` = winner.`workline_code`
   AND baseline.`next_hour` = winner.`hour_24num`
SET src.`cal_status` = IF(winner.`id` IS NULL OR winner.`total_output` = 0, 3, 2),
    src.`hour_24num` = winner.`hour_24num`,
    src.`time_output` = CASE
        WHEN winner.`total_output` = 0 THEN NULL
        ELSE winner.`total_output` - COALESCE(baseline.`total_output`, winner.`historical_output`)
    END,
    src.`modify_time` = NOW(),
    src.`modify_by` = 0
WHERE src.`cal_status` = 1
  AND src.`rec_status` = 1;

-- 清理本次任务的临时表。
DROP TEMPORARY TABLE IF EXISTS `mwx_production_statistics_scope_tmp`, `mwx_production_statistics_closest_tmp`,
    `mwx_production_statistics_winner_tmp`, `mwx_production_statistics_baseline_tmp`;
