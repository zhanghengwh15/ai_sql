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
  `cal_status` tinyint NULL DEFAULT 1 COMMENT '计算状态 初始化 1',
  PRIMARY KEY (`id`)
) COMMENT='美味鲜-产线产量统计';

-- 给这个新增一个计算表  两个字段  对应的是整点的时刻，比较靠近的整点时间计算差值。同时还需要加上对应的表计的 code 






