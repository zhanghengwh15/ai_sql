-- =============================================================
-- 表名：yt_produce_work_order（燕塘生产工单中台表）
-- 数据库：MySQL 8
-- 来源：生产工单分页接口 data.records[]
-- 用途：承接燕塘生产工单数据，为生产报工提供工单、物料和动态字段信息
-- 说明：分页元数据 total、size、current、pages 不属于工单业务数据，不落表
-- =============================================================

CREATE TABLE `yt_mid_produce_work_order` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `eid` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '企业ID，对应eid',
  `work_order_template_name` VARCHAR(256) DEFAULT NULL COMMENT '工单模板名称，对应workOrderTemplateName',
  `work_order_number` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '生产工单号，对应workOrderNumber，应用层按eid和工单号保证唯一',
  `factory_alias` VARCHAR(128) DEFAULT NULL COMMENT '工厂单元别名，对应factoryAlias',
  `material_code` VARCHAR(128) DEFAULT NULL COMMENT '产品物料编码，对应materialCode',
  `plan_finish_quantity` DECIMAL(22,6) DEFAULT NULL COMMENT '计划产量，对应planFinishQuantity',
  `measure_unit` VARCHAR(64) DEFAULT NULL COMMENT '产品计量单位，对应measureUnit',

  `plan_begin_time` DATETIME DEFAULT NULL COMMENT '计划开始时间，对应planBeginTime',
  `plan_end_time` DATETIME DEFAULT NULL COMMENT '计划结束时间，对应planEndTime',
  `real_begin_time` DATETIME DEFAULT NULL COMMENT '实际开始时间，对应realBeginTime',
  `real_end_time` DATETIME DEFAULT NULL COMMENT '实际结束时间，对应realEndTime',
  `audit_status` TINYINT(4) DEFAULT NULL COMMENT '审核状态：0-未审核，1-已审核，对应auditStatus',
  `issue_status` TINYINT(4) DEFAULT NULL COMMENT '下发状态：0-未下发，1-已下发，对应issueStatus',
  `execute_status` TINYINT(4) DEFAULT NULL COMMENT '执行状态：0-未开始，1-生产中，2-已完成，3-已取消，4-已关闭，5-已暂停，对应executeStatus',
  `out_status` TINYINT(4) DEFAULT NULL COMMENT '出仓状态，对应outStatus',

  `source_create_time` DATETIME DEFAULT NULL COMMENT '上游创建时间，对应createTime',
  `source_modify_time` DATETIME DEFAULT NULL COMMENT '上游更新时间，对应modifyTime',
  `source_modify_by_name` VARCHAR(128) DEFAULT NULL COMMENT '上游更新人账号，对应modifyByName',
  `audit_time` DATETIME DEFAULT NULL COMMENT '审核时间，对应auditTime',
  `audit_by_name` VARCHAR(128) DEFAULT NULL COMMENT '审核人账号，对应auditByName',
  `issue_time` DATETIME DEFAULT NULL COMMENT '下发时间，对应issueTime',
  `issue_by_name` VARCHAR(128) DEFAULT NULL COMMENT '下发人账号，对应issueByName',


  `dynamic_field` JSON DEFAULT NULL COMMENT '工单动态字段，对应dynamicField，键和值由工单模板动态定义',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '中台记录创建时间',
  `modify_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '中台记录更新时间',
  `rec_status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='燕塘生产工单中台表';
