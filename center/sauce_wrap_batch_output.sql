-- =============================================================
-- 表名：mes_sauce_wrap_batch_output（包装批次产量中台表）
-- 数据库：MySQL 8
-- 来源：GET /api/fm-product-manage/batchOutput/sauce/wrap
-- 说明：承接包装批次产量数据
-- =============================================================

CREATE TABLE `mes_sauce_wrap_batch_output` (
  `id`               bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',

  `work_date`        date          NOT NULL COMMENT '生产日期，对应请求参数 workDate',
  `batch_no`         varchar(100)  NOT NULL DEFAULT '' COMMENT '批次号，对应 batchNo',
  `batch_start_time` datetime(3)            DEFAULT NULL COMMENT '批次开始时间，对应 batchStartTime',
  `batch_end_time`   datetime(3)            DEFAULT NULL COMMENT '批次结束时间，对应 batchEndTime',

  `line_name`        varchar(100)  NOT NULL DEFAULT '' COMMENT '生产线，对应 lineName',
  `material_code`    varchar(100)  NOT NULL DEFAULT '' COMMENT '物料编码，对应 materialCode',
  `material_name`    varchar(255)  NOT NULL DEFAULT '' COMMENT '物料名称，对应 materialName',
  `quantity`         decimal(18,6) NOT NULL DEFAULT 0.000000 COMMENT '批次量，对应 quantity',

  `team_code`        varchar(64)   NOT NULL DEFAULT '' COMMENT '班组编码，对应 teamCode',
  `team_name`        varchar(100)  NOT NULL DEFAULT '' COMMENT '班组名称，对应 teamName',
  `unit_code`        varchar(64)   NOT NULL DEFAULT '' COMMENT '单位编码，对应 unitCode',
  `unit_name`        varchar(64)   NOT NULL DEFAULT '' COMMENT '单位名称，对应 unitName',

  `create_time`      datetime(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '中台记录创建时间',
  `modify_time`      datetime(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                            ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '中台记录修改时间',
  `rec_status`       tinyint(4)    NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',

  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='【mes】 包装批次产量中台表';
