-- 仅在测试库执行一次：先执行 cal_任务.sql 的建表段，再插入本批 mock 数据，最后运行计算段。
-- 主产线预期：00:00 为日切重置 0.000 且状态为 3，01:00 = 160.000，02:00 = 20.000，04:00 缺上一小时，差值为 NULL。
-- 本批 task_record_id 为 9826112401；不同 eid 的同厂同产线样本仍一起选样。
INSERT INTO `mwx_production_statistics` (
    `task_record_id`, `eid`, `factory_code`, `factory_name`, `workline_code`, `workline_name`,
    `create_time`, `total_output`, `rec_status`, `cal_status`, `hour_24num`, `time_output`
) VALUES
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-23 22:59:59', 100.000, 1, 2, '2026-11-23 23:00:00', NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-23 23:00:00', 101.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-23 23:56:00', 118.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-23 23:59:00', 125.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E02', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 00:00:00', 0.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E02', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 00:01:00', 126.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E02', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 01:00:00', 160.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 01:30:00', 180.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 04:00:00', 240.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F02', '测试工厂二', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 00:00:00', 300.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L02', '测试产线二', '2026-11-24 00:00:00', 400.000, 1, 1, NULL, NULL),
    (9826112401, 'MOCK_E01', 'MOCK_CAL_F01', '测试工厂一', 'MOCK_CAL_L01', '测试产线一', '2026-11-24 00:00:00', 999.000, 0, 1, NULL, NULL);
