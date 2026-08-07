-- =============================================================
-- 表名：mes_sauce_disk_check_result（美味鲜圆盘送检结果中台表）
-- 数据库：MySQL 8
-- 来源：GET /api/fm-quality-manage/batchCheckApi/diskCheckResult
-- 说明：按批号同步圆盘送检结果；一行对应同一批号的一次送检。
--       check_item_vo_list 保留上游检测指标 JSON 数组，不拆分检测项目明细表。
-- 幂等键：batch_no + check_num，由同步程序在应用层保证。
-- =============================================================

CREATE TABLE `mes_sauce_disk_check_result` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',

  `batch_no` varchar(128) NOT NULL DEFAULT '' COMMENT '批次号，对应batchNo',
  `check_num` int(11) NOT NULL DEFAULT 0 COMMENT '送检次数，对应checkNum；同一批次内递增',
  `accept_code` varchar(128) DEFAULT NULL COMMENT '送检单号，对应acceptCode',

  `line_code` varchar(64) DEFAULT NULL COMMENT '产线编码，对应lineCode',
  `line_name` varchar(128) DEFAULT NULL COMMENT '产线名称，对应lineName',
  `material_code` varchar(128) DEFAULT NULL COMMENT '物料编码，对应materialCode',
  `material_name` varchar(256) DEFAULT NULL COMMENT '物料名称，对应materialName',
  `process_code` varchar(64) DEFAULT NULL COMMENT '工序编码，对应processCode',
  `process_name` varchar(128) DEFAULT NULL COMMENT '工序名称，对应processName',
  `sample_code` varchar(128) DEFAULT NULL COMMENT '样品编码，对应sampleCode',
  `sample_name` varchar(256) DEFAULT NULL COMMENT '样品名称，对应sampleName',
  `sampling_point` varchar(128) DEFAULT NULL COMMENT '取样点，对应samplingPoint',

  `initiate_user` varchar(128) DEFAULT NULL COMMENT '送检人，对应initiateUser',
  `initiate_time` datetime DEFAULT NULL COMMENT '送检时间，对应initiateTime',
  `feedback_time` datetime DEFAULT NULL COMMENT '结果反馈时间，对应feedbackTime',
  `qualified` varchar(8) DEFAULT NULL COMMENT '送检整体判定：0-不合格，1-合格，2-未判定，对应qualified',
  `status_name` varchar(32) DEFAULT NULL COMMENT '送检状态：01-已发起，02-已送检，03-已接收，04-已检验；上游可能返回状态名称，对应statusName',

  `check_item_vo_list` json DEFAULT NULL COMMENT '检验指标结果集，对应checkItemVOList；JSON数组，未拆分明细表',

  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '中台记录创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '中台记录修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',

  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='【mes】美味鲜圆盘送检结果中台表';
