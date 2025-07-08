-- 工单批次打印表
-- 用于记录生产工单的批次打印信息
CREATE TABLE `work_order_batch_print` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `work_order_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '工单id',
  `work_order_no` varchar(64) NOT NULL DEFAULT '' COMMENT '生产工单号',
  `print_copies` int(11) NOT NULL DEFAULT 1 COMMENT '打印份数',
  `batch_no` varchar(64) NOT NULL DEFAULT '' COMMENT '批次号',
  `batch_quantity` int(11) NOT NULL DEFAULT 0 COMMENT '批次产量',
  `print_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '打印人ID',
  `print_time` datetime NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '打印时间',
  `feeding_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '投料人ID',
  `feeding_time` datetime NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '投料时间',
  `status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '状态：1-未投料，2-已经投料',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='工单批次打印表';

-- 后续根据业务查询需求添加索引，例如：
-- 1. 按机构+工单号查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_work_order_no` (`org_id`, `work_order_no`);

-- 2. 按机构+批次号查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_batch_no` (`org_id`, `batch_no`);

-- 3. 按机构+打印时间查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_print_time` (`org_id`, `print_time`);

-- 4. 按机构+状态查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_status` (`org_id`, `status`);

-- 5. 防止同一机构下工单号+批次号重复
-- ALTER TABLE `work_order_batch_print` ADD UNIQUE KEY `uk_org_work_order_batch` (`org_id`, `work_order_no`, `batch_no`);

-- 6. 按机构+投料时间查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_feeding_time` (`org_id`, `feeding_time`);

-- 7. 按机构+状态+打印时间查询
-- ALTER TABLE `work_order_batch_print` ADD KEY `idx_org_status_print_time` (`org_id`, `status`, `print_time`); 