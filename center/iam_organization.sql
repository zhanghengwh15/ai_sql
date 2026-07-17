-- =============================================================
-- 表名：mid_iam_organization（IAM 组织中台表）
-- 数据库：MySQL 8
-- 来源：ExtApiIngtOrganizationService/findBy
-- 说明：承接 IAM 组织、部门全量及增量同步数据，不包含 org_id 字段
-- =============================================================

CREATE TABLE `mid_iam_organization` (
  `id`                  bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',

  `tree_id`             varchar(64)  NOT NULL DEFAULT '' COMMENT '机构树编码，对应 treeId',
  `sequence`            varchar(64)  NOT NULL DEFAULT '' COMMENT '序号，对应 sequence',
  `guid`                varchar(64)  NOT NULL DEFAULT '' COMMENT 'NC主键，对应 guid',
  `code`                varchar(128) NOT NULL DEFAULT '' COMMENT '组织编码；部门格式通常为组织编码-部门编码',
  `name`                varchar(255) NOT NULL DEFAULT '' COMMENT '组织或部门名称',
  `parent_id`           varchar(128) NOT NULL DEFAULT '' COMMENT '上级机构虚拟主键，对应 parentId；空字符串表示根节点',
  `organization_type`   varchar(32)  NOT NULL DEFAULT '' COMMENT '机构类型：company-组织，department-部门，对应 type',
  `is_disabled`         tinyint(1)   NOT NULL DEFAULT 0 COMMENT '是否禁用：0-启用，1-禁用，对应 isDisabled',
  `is_deleted`          tinyint(1)   NOT NULL DEFAULT 0 COMMENT '源数据是否删除：0-否，1-是，对应 isDeleted',

  `cost_team_name`      varchar(255) NOT NULL DEFAULT '' COMMENT '成本班组名称，对应 cbbz，仅部门有值',
  `cost_team_code`      varchar(128) NOT NULL DEFAULT '' COMMENT '成本班组编码，对应 cbbzcode，仅部门有值',
  `principal`           varchar(255) NOT NULL DEFAULT '' COMMENT '负责人，对应 principal，仅部门有值',
  `charge_leader`       varchar(255) NOT NULL DEFAULT '' COMMENT '分管领导，对应 chargeleader，仅部门有值',

  `nc_data`             json                  DEFAULT NULL COMMENT 'NC原始数据，对应 ncdata',
  `nc_id`               varchar(64)  NOT NULL DEFAULT '' COMMENT 'NC主键，对应 _AID',
  `bim_id`              varchar(128) NOT NULL DEFAULT '' COMMENT 'BIM端主键，对应 _BID',
  `external_id`         varchar(128) NOT NULL COMMENT '虚拟外部接口主键，对应 _ID',
  `display_path`        varchar(2000) NOT NULL DEFAULT '' COMMENT '机构全路径，对应 zzDisplayPath',
  `process_status`      varchar(32)  NOT NULL DEFAULT '' COMMENT '源数据处理状态，对应 zzProcessStatus',
  `nc_creation_time`    datetime(3)           DEFAULT NULL COMMENT 'NC数据创建时间，对应 creationtime',

  `source_create_at`    datetime(3)           DEFAULT NULL COMMENT '接口记录创建时间，对应 createAt',
  `source_update_at`    datetime(3)           DEFAULT NULL COMMENT '接口记录更新时间，对应 updateAt，增量同步游标',

  `create_time`         datetime(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '中台记录创建时间',
  `modify_time`         datetime(3)  NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                           ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '中台记录修改时间',
  `rec_status`          tinyint(4)   NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',

  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_mid_iam_organization_external_id` (`external_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='IAM组织中台表';

