-- =============================================================
-- 表名：produce_work_order_main（生产工单主表）
-- 数据库：poit-product（或按实际调整）
-- 说明：记录生产工单的核心单据信息与出仓执行状态
-- 创建时间：2026-06-03
-- =============================================================

CREATE TABLE `produce_work_order_main` (
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
