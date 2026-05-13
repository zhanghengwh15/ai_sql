-- =====================================================================
-- 业务名称：奇峰纸业-删除入库量同步回写（产成品入库单列表 / 出仓）
-- 源表：    qfzy_delete_data_sync
-- 目标表：  qfzy_productinlist、qfzy_productin_cc
-- 触发方式：定时任务 / 手动执行（建议单连接串行跑批）
-- 说明：    单套范围临时表（扩列锁定 id + 业务键 + 载荷），UPDATE 时
--           INNER JOIN 原同步表与目标业务表，「命中关联」即成功子集，
--           不再单独建 Staging 临时表（见 sql-temp-table-writer SKILL）。
-- 验证：    调试用 SELECT 一律包在块注释 /* ... */ 中，执行前去掉定界符。
-- 前置：    目标表需存在 `qfzy_productinlist`.`is_deleted`、
--           `qfzy_productin_cc`.`is_deleted`（若列名不同请全局替换）。
-- 日期：    2026-05-08
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 收尾保险：先清理可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `qfzy_delete_sync_list_scope_tmp`;
DROP TEMPORARY TABLE IF EXISTS `qfzy_delete_sync_cc_scope_tmp`;

-- #####################################################################
-- 阶段一：sync_status = 2 → 按 biz_code 回写 qfzy_productinlist.is_deleted
--         仅当存在匹配 code 的入库单列表行时，再将该同步行 sync_status 置 5
-- #####################################################################

-- ---------------------------------------------------------------------
-- 1. 范围临时表：锁定本批同步行，并带上列表更新所需字段（免再建 Staging）
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `qfzy_delete_sync_list_scope_tmp` AS (
  SELECT
    `id`,
    `biz_code`,
    `is_delete` AS `src_is_deleted`
  FROM `qfzy_delete_data_sync`
  WHERE `sync_status` = 2
    AND `rec_status` = 1
    AND `biz_code` <> ''
    AND `modify_time` >= NOW() - INTERVAL 24 HOUR
  ORDER BY `id`
  LIMIT 5000
);

/* 验证 SQL-1：阶段一锁定范围
SELECT COUNT(*) AS lock_cnt FROM `qfzy_delete_sync_list_scope_tmp`;

SELECT s.*, d.`sync_status`, d.`modify_time`
FROM `qfzy_delete_sync_list_scope_tmp` s
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
LIMIT 20;
*/

/* 验证 SQL-2：本批「能命中列表」数量（与后续置 sync_status=5 逻辑一致）
SELECT COUNT(*) AS hit_list_cnt
FROM `qfzy_delete_sync_list_scope_tmp` s
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
JOIN `qfzy_productinlist` l
  ON l.`code` = s.`biz_code` AND l.`rec_status` = 1
WHERE d.`sync_status` = 2 AND d.`rec_status` = 1;
*/

-- ---------------------------------------------------------------------
-- 2. 写入业务表：范围表 + 原表 INNER JOIN，仅命中列表的行被更新
-- ---------------------------------------------------------------------
UPDATE `qfzy_productinlist` l
INNER JOIN `qfzy_delete_sync_list_scope_tmp` s
  ON l.`code` = s.`biz_code`
INNER JOIN `qfzy_delete_data_sync` d
  ON d.`id` = s.`id`
SET
  l.`is_deleted`  = s.`src_is_deleted`,
  l.`modify_time` = NOW(),
  l.`modify_by`   = 0
WHERE l.`rec_status` = 1
  AND d.`sync_status` = 2
  AND d.`rec_status` = 1
;

/* 验证 SQL-3：抽样核对列表 is_deleted
SELECT l.`id`, l.`code`, l.`is_deleted`, s.`src_is_deleted`
FROM `qfzy_productinlist` l
JOIN `qfzy_delete_sync_list_scope_tmp` s ON l.`code` = s.`biz_code`
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
WHERE l.`rec_status` = 1 AND d.`sync_status` IN (2, 5)
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 3. 回写同步表：JOIN 列表，仅真正命中列表的同步行置 sync_status = 5
-- ---------------------------------------------------------------------
UPDATE `qfzy_delete_data_sync` d
INNER JOIN `qfzy_delete_sync_list_scope_tmp` s
  ON d.`id` = s.`id`
SET
  d.`sync_status` = 5,
  d.`modify_time` = NOW(),
  d.`modify_by`   = 0
WHERE d.`sync_status` = 2
  AND d.`rec_status` = 1
;

-- 【可选】将「已锁定但无匹配列表」的同步行标为失败，避免长期卡在 2
-- UPDATE `qfzy_delete_data_sync` d
-- INNER JOIN `qfzy_delete_sync_list_scope_tmp` s ON d.`id` = s.`id`
-- SET d.`sync_status` = 3,
--     d.`remark`      = CONCAT(IFNULL(d.`remark`, ''), ' | 无匹配产成品入库单列表 code'),
--     d.`modify_time` = NOW(),
--     d.`modify_by`   = 0
-- WHERE d.`sync_status` = 2
--   AND NOT EXISTS (
--     SELECT 1 FROM `qfzy_productinlist` l
--     WHERE l.`code` = s.`biz_code` AND l.`rec_status` = 1
--   );

/* 验证 SQL-4：阶段一回写后 sync_status 分布
SELECT d.`sync_status`, COUNT(*) AS cnt
FROM `qfzy_delete_data_sync` d
WHERE d.`id` IN (SELECT `id` FROM `qfzy_delete_sync_list_scope_tmp`)
GROUP BY d.`sync_status`;
*/

/* 验证 SQL-5：反向检查（无匹配列表却为 5 → 逻辑错误）
SELECT d.`id`, d.`biz_code`, d.`sync_status`
FROM `qfzy_delete_data_sync` d
INNER JOIN `qfzy_delete_sync_list_scope_tmp` s ON d.`id` = s.`id`
LEFT JOIN `qfzy_productinlist` l
  ON l.`code` = s.`biz_code` AND l.`rec_status` = 1
WHERE d.`sync_status` = 5 AND l.`id` IS NULL;
*/

-- ---------------------------------------------------------------------
-- 阶段一临时表清理
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `qfzy_delete_sync_list_scope_tmp`;

-- #####################################################################
-- 阶段二：is_delete = 1 且 sheet_status = 1 →
--         将 qfzy_productin_cc 中 code = biz_code 的行 is_deleted = 1
-- #####################################################################

-- ---------------------------------------------------------------------
-- 4. 范围临时表：锁定本批 + 带出 biz_code（UPDATE 时直接 JOIN 原表）
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE `qfzy_delete_sync_cc_scope_tmp` AS (
  SELECT
    `id`,
    `biz_code`
  FROM `qfzy_delete_data_sync`
  WHERE `is_delete` = 1
    AND `sheet_status` = 1
    AND `rec_status` = 1
    AND `biz_code` <> ''
    AND `modify_time` >= NOW() - INTERVAL 24 HOUR
  ORDER BY `id`
  LIMIT 5000
);

/* 验证 SQL-6：阶段二锁定范围
SELECT COUNT(*) AS lock_cnt FROM `qfzy_delete_sync_cc_scope_tmp`;

SELECT s.*, d.`is_delete`, d.`sheet_status`
FROM `qfzy_delete_sync_cc_scope_tmp` s
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
LIMIT 20;
*/

/* 验证 SQL-7：本批能命中出仓表的数量
SELECT COUNT(*) AS hit_cc_cnt
FROM `qfzy_delete_sync_cc_scope_tmp` s
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
JOIN `qfzy_productin_cc` c
  ON c.`code` = s.`biz_code` AND c.`rec_status` = 1
WHERE d.`is_delete` = 1 AND d.`sheet_status` = 1 AND d.`rec_status` = 1;
*/

-- ---------------------------------------------------------------------
-- 5. 更新出仓表：范围表 + 原表 INNER JOIN，仅命中的明细行被更新
-- ---------------------------------------------------------------------
UPDATE `qfzy_productin_cc` c
INNER JOIN `qfzy_delete_sync_cc_scope_tmp` s
  ON c.`code` = s.`biz_code`
INNER JOIN `qfzy_delete_data_sync` d
  ON d.`id` = s.`id`
SET
  c.`is_deleted`  = 1,
  c.`modify_time` = NOW(),
  c.`modify_by`   = 0
WHERE c.`rec_status` = 1
  AND d.`is_delete` = 1
  AND d.`sheet_status` = 1
  AND d.`rec_status` = 1
;

/* 验证 SQL-8：出仓表抽样
SELECT c.`id`, c.`code`, c.`is_deleted`
FROM `qfzy_productin_cc` c
JOIN `qfzy_delete_sync_cc_scope_tmp` s ON c.`code` = s.`biz_code`
JOIN `qfzy_delete_data_sync` d ON d.`id` = s.`id`
WHERE c.`rec_status` = 1
LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 6. 收尾：删除全部临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS `qfzy_delete_sync_cc_scope_tmp`;

