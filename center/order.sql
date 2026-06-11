-- =============================================================
-- 表名：produce_work_order_main（生产工单主表）
-- 数据库：poit-product（或按实际调整）
-- 说明：记录生产工单的核心单据信息与出仓执行状态
-- 创建时间：2026-06-03
-- =============================================================

CREATE TABLE `yt_produce_work_order` (
  `id`           bigint(20) unsigned NOT NULL AUTO_INCREMENT     COMMENT '主键ID',

  `doc_no`       varchar(64)  NOT NULL DEFAULT ''                COMMENT '单据编号（业务单号，全局唯一）',
  `work_order_id` bigint(20) unsigned NOT NULL DEFAULT 0         COMMENT '生产工单号（关联上游工单ID）',
  `status`       tinyint(4)   NOT NULL DEFAULT 1
    COMMENT '工单状态："0：未开始 1：生产中 2：已完成 3：已取消 4：已关闭  5：已暂停',
  `out_status`   tinyint(4)   NOT NULL DEFAULT 0
    COMMENT '出仓状态：1-未出仓，2-成功出仓，3-出仓失败）',

  `eid`       varchar(64) NOT NULL DEFAULT ''           COMMENT 'eid',
  `create_by`    bigint(20) unsigned NOT NULL DEFAULT 0          COMMENT '创建人ID',
  `modify_by`    bigint(20) unsigned NOT NULL DEFAULT 0          COMMENT '修改人ID',
  `create_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time`  datetime     NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP        COMMENT '修改时间',
  `rec_status`   tinyint(4)   NOT NULL DEFAULT 1                 COMMENT '记录状态：1-有效，0-删除',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='生产工单主表';

-- ── 后续按实际查询场景添加索引 ─────────────────────────────
-- 按单据编号查询（唯一）
-- ALTER TABLE `produce_work_order_main` ADD UNIQUE KEY `uk_doc_no` (`doc_no`);

-- 多租户下按工单状态查询
-- ALTER TABLE `produce_work_order_main` ADD KEY `idx_org_status` (`org_id`, `status`);

-- 多租户下按出仓状态查询
-- ALTER TABLE `produce_work_order_main` ADD KEY `idx_org_out_status` (`org_id`, `out_status`);

-- 按上游工单ID查询
-- ALTER TABLE `produce_work_order_main` ADD KEY `idx_work_order_id` (`work_order_id`);




-- 生产报工记录表
-- 用途：记录生产报工详细信息，包含报工物料、数量、时间等关键信息
-- 项目前缀：yt（燕塘业务）
CREATE TABLE `yt_production_report` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  

  `unique_code` varchar(100) NOT NULL DEFAULT '' COMMENT '唯一编码',
  `unique_type` tinyint(4) NOT NULL DEFAULT 1 COMMENT '唯一类型：1-默认类型',
  

  `produce_work_order_no` varchar(100) NOT NULL DEFAULT '' COMMENT '生产工单号',
  `material_code` varchar(100) NOT NULL DEFAULT '' COMMENT '报工物料编码',
  `sheet_batch_no` varchar(100) NOT NULL DEFAULT '' COMMENT '完工批次号',
  
  `output` decimal(18,4) NOT NULL DEFAULT 0.0000 COMMENT '报工数量',
  `output_type` tinyint(4) NOT NULL DEFAULT 1 COMMENT '报工数量类型：1-默认类型',
  `grade_name` varchar(100) NOT NULL DEFAULT '' COMMENT '等级名称',
  `send_date` date NOT NULL DEFAULT '1970-01-01' COMMENT '报工日期',
  `sheet_time` datetime NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '报工时间',
  `sheet_username` varchar(100) NOT NULL DEFAULT '' COMMENT '报工人账号ID',
  
  -- 报工单元信息
  `factory_area_alias` varchar(100) NOT NULL DEFAULT '' COMMENT '报工单元别名',
  `course_alias` varchar(100) NOT NULL DEFAULT '' COMMENT '报工班组别名',
  `shift_alias` varchar(100) NOT NULL DEFAULT '' COMMENT '报工班次别名',
  
  `container_code` varchar(100) NOT NULL DEFAULT '' COMMENT '容器编码',
  `store_code` varchar(100) NOT NULL DEFAULT '' COMMENT '入库库位',
  
  -- 自定义字段（JSON格式存储动态扩展字段）
  `custom_fields` json DEFAULT NULL COMMENT '自定义字段（JSON格式，存储托盘号等动态扩展信息）',
  
  -- 备注信息
  `remark` varchar(512) NOT NULL DEFAULT '' COMMENT '备注',
  
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='生产报工记录表';


