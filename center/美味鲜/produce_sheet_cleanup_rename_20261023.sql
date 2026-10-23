-- MySQL 8：按提供的 DDL，保留正常记录的 sheet_id，复制后换表。
-- 先暂停业务、中台同步及定时任务的写入，等待已有写事务结束。
-- 以下在目标库的同一独立连接中执行，完成后再恢复写入。
-- 前提：无需要迁移的触发器或数据库外键依赖；新表和备份表名未被占用。
-- 任一步报错即停止，不继续执行后面的语句。
SET SESSION autocommit = 1;

-- 1. 记录原表当前自增位置。
SELECT AUTO_INCREMENT INTO @next_sheet_id
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = DATABASE()
  AND TABLE_NAME = 'produce_sheet';

-- 2. 复制原表结构（包含主键、索引等）。
CREATE TABLE produce_sheet_clean_20261023 LIKE produce_sheet;

-- 3. 仅复制正常数据，sheet_id 及其他字段原值保留。
-- 提供的 DDL 无生成列和不可见列，可直接使用 SELECT *。
INSERT INTO produce_sheet_clean_20261023
SELECT *
FROM produce_sheet
WHERE (
    factory_area_id = 101552
    AND org_id = 100002
    AND status = 2
    AND modify_time BETWEEN '2026-10-21 00:00:00'
                        AND '2026-10-23 15:00:00'
) IS NOT TRUE;

-- 4. 沿用原表自增位置，不复用问题数据曾占用的 ID。
SET @alter_sql = CONCAT(
    'ALTER TABLE produce_sheet_clean_20261023 AUTO_INCREMENT = ',
    @next_sheet_id
);
PREPARE stmt FROM @alter_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 5. 一次性交换表名，旧表作为备份保留。
RENAME TABLE
    produce_sheet TO produce_sheet_backup_20261023,
    produce_sheet_clean_20261023 TO produce_sheet;

-- 执行成功后恢复业务，异常中台写入入口应修复后再恢复。
-- 原表备份先保留，不要立即删除。
