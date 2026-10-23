-- 本文件仅操作 mock 表，与正式换表脚本采用相同逻辑。
-- 先运行 produce_sheet_mock_data.sql。本文件仅运行一次；任一步报错即停止。
-- 换表后应剩 10 条，sheet_id 原值不变；备份表仍有全部 14 条。
-- 保留 ID：101,120,125,130,140,150,160,170,180,190。

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
  AND TABLE_NAME = 'produce_sheet_mock';

-- 2. 复制原表结构（包含主键、索引等）。
CREATE TABLE produce_sheet_mock_clean_20261023 LIKE produce_sheet_mock;

-- 3. 仅复制正常数据，sheet_id 及其他字段原值保留。
-- 提供的 DDL 无生成列和不可见列，可直接使用 SELECT *。
INSERT INTO produce_sheet_mock_clean_20261023
SELECT *
FROM produce_sheet_mock
WHERE (
    factory_area_id = 101552
    AND org_id = 100002
    AND status = 2
    AND modify_time BETWEEN '2026-10-21 00:00:00'
                        AND '2026-10-23 15:00:00'
) IS NOT TRUE;

-- 4. 沿用原表自增位置，不复用问题数据曾占用的 ID。
SET @alter_sql = CONCAT(
    'ALTER TABLE produce_sheet_mock_clean_20261023 AUTO_INCREMENT = ',
    @next_sheet_id
);
PREPARE stmt FROM @alter_sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- 5. 一次性交换表名，旧表作为备份保留。
RENAME TABLE
    produce_sheet_mock TO produce_sheet_mock_backup_20261023,
    produce_sheet_mock_clean_20261023 TO produce_sheet_mock;

-- 执行成功后恢复业务，异常中台写入入口应修复后再恢复。
-- 原表备份先保留，不要立即删除。

-- 查看结果：应为 10 条，ID 与上面的保留清单一致。
SELECT sheet_id, note FROM produce_sheet_mock ORDER BY sheet_id;

-- 测试新增：应得到 sheet_id = 1001，不会从保留数据的最大 ID 190 后接着编号。
INSERT INTO produce_sheet_mock (note) VALUES ('换表后新增，自增 ID 应为 1001');
SELECT LAST_INSERT_ID() AS new_sheet_id;
-- 此时总数为 11 条，备份表不变。

-- 索引也应保留，可以查看主键和全部二级索引。
SHOW INDEX FROM produce_sheet_mock;
