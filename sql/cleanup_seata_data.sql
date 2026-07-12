-- =====================================================================
-- 业务名称：Seata 无效事务数据清理
-- 主表：    global_table, branch_table, lock_table
-- 备份表：  global_table_backup, branch_table_backup, lock_table_backup
-- 触发方式：手动执行
-- 作者：    AI生成    日期：2026-06-29
-- 说明：    清理 status = 12 或 14 的 Seata 无效事务数据，清理前先备份
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. 收尾保险：先清理可能残留的临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS seata_cleanup_scope_tmp;
DROP TEMPORARY TABLE IF EXISTS seata_cleanup_xid_tmp;

-- ---------------------------------------------------------------------
-- 1. 临时表 A：锁定本次要处理的 xid 范围（从 copy5 表获取）
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE seata_cleanup_scope_tmp AS (
  SELECT `xid`
  FROM `global_table_copy5`
  WHERE `status` IN (12, 14)
  ORDER BY `xid`
  LIMIT 100
);

/* 验证 SQL-1：确认本次锁定的范围（执行前去掉本块首尾块注释定界符）
SELECT COUNT(*) AS lock_cnt FROM seata_cleanup_scope_tmp;
SELECT * FROM seata_cleanup_scope_tmp LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 2. 临时表 B：从 copy10 表获取要删除的 xid（独立范围，避免混淆）
-- ---------------------------------------------------------------------
CREATE TEMPORARY TABLE seata_cleanup_xid_tmp AS (
  SELECT `xid`
  FROM `global_table_copy10`
  WHERE `status` IN (12, 14)
  ORDER BY `xid`
  LIMIT 100
);

/* 验证 SQL-2：确认要删除的 xid 范围
SELECT COUNT(*) AS delete_cnt FROM seata_cleanup_xid_tmp;
SELECT * FROM seata_cleanup_xid_tmp LIMIT 20;
*/

-- ---------------------------------------------------------------------
-- 3. 备份数据：从 copy5 表备份到 backup 表
-- ---------------------------------------------------------------------
-- 备份 global_table
INSERT INTO `global_table_backup`
SELECT g.*
FROM `global_table_copy5` g
INNER JOIN seata_cleanup_scope_tmp s ON g.`xid` = s.`xid`;

-- 备份 branch_table
INSERT INTO `branch_table_backup`
SELECT b.*
FROM `branch_table_copy5` b
INNER JOIN seata_cleanup_scope_tmp s ON b.`xid` = s.`xid`;

-- 备份 lock_table
INSERT INTO `lock_table_backup`
SELECT l.*
FROM `lock_table_copy5` l
INNER JOIN seata_cleanup_scope_tmp s ON l.`xid` = s.`xid`;

/* 验证 SQL-3：确认备份数据量
SELECT
  (SELECT COUNT(*) FROM `global_table_backup` WHERE `xid` IN (SELECT `xid` FROM seata_cleanup_scope_tmp)) AS global_backup_cnt,
  (SELECT COUNT(*) FROM `branch_table_backup` WHERE `xid` IN (SELECT `xid` FROM seata_cleanup_scope_tmp)) AS branch_backup_cnt,
  (SELECT COUNT(*) FROM `lock_table_backup` WHERE `xid` IN (SELECT `xid` FROM seata_cleanup_scope_tmp)) AS lock_backup_cnt;
*/

-- ---------------------------------------------------------------------
-- 4. 删除关联无效数据：从正式表删除（使用临时表 JOIN）
-- ---------------------------------------------------------------------
-- 先删除 branch_table
DELETE b
FROM `branch_table` b
INNER JOIN seata_cleanup_xid_tmp s ON b.`xid` = s.`xid`;

-- 再删除 lock_table
DELETE l
FROM `lock_table` l
INNER JOIN seata_cleanup_xid_tmp s ON l.`xid` = s.`xid`;

-- 最后删除 global_table（直接按 status 删除，因为这是最终目标）
DELETE FROM `global_table`
WHERE `status` IN (12, 14);

/* 验证 SQL-4：确认删除结果
SELECT
  (SELECT COUNT(*) FROM `branch_table` WHERE `xid` IN (SELECT `xid` FROM seata_cleanup_xid_tmp)) AS branch_remaining,
  (SELECT COUNT(*) FROM `lock_table` WHERE `xid` IN (SELECT `xid` FROM seata_cleanup_xid_tmp)) AS lock_remaining,
  (SELECT COUNT(*) FROM `global_table` WHERE `status` IN (12, 14)) AS global_remaining;
*/

-- ---------------------------------------------------------------------
-- 5. 收尾：清理临时表
-- ---------------------------------------------------------------------
DROP TEMPORARY TABLE IF EXISTS seata_cleanup_scope_tmp;
DROP TEMPORARY TABLE IF EXISTS seata_cleanup_xid_tmp;
