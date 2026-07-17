-- =============================================================
-- 表名：mid_iam_user（IAM 用户中台表）
-- 数据库：MySQL 8
-- 来源：ExtApiIngtUserService/findBy
-- 说明：承接 IAM 用户全量及按 updateAt 增量同步数据
-- =============================================================

CREATE TABLE `mid_iam_user` (
  `id`                    bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',

  `username`              varchar(128)  NOT NULL COMMENT '员工工号，对应 username',
  `full_name`             varchar(255)  NOT NULL DEFAULT '' COMMENT '员工名称，对应 fullname',
  `user_type_id`          varchar(64)   NOT NULL DEFAULT '' COMMENT '用户类型，对应 typeId，如 EMPLOYEE',
  `gender`                char(1)       NOT NULL DEFAULT '' COMMENT '性别：1-男，2-女，对应 gender',
  `id_type`               varchar(64)   NOT NULL DEFAULT '' COMMENT '证件类型，对应 idtype',
  `identity_card`         varchar(1024) NOT NULL DEFAULT '' COMMENT '身份证号（接口可能返回密文），对应 identityCard',
  `mobile`                varchar(1024) NOT NULL DEFAULT '' COMMENT '手机号码（接口可能返回密文），对应 mobile',
  `email`                 varchar(1024) NOT NULL DEFAULT '' COMMENT '邮箱（接口可能返回密文），对应 email',
  `birth_date`            date                   DEFAULT NULL COMMENT '生日，对应 birthdate',
  `join_date`             date                   DEFAULT NULL COMMENT '入职日期，对应 joindate',
  `quit_date`             date                   DEFAULT NULL COMMENT '离职日期，对应 quitdate',

  `company_id`            varchar(128)  NOT NULL DEFAULT '' COMMENT '所属组织编码，对应 companyId',
  `job_company_id`        varchar(128)  NOT NULL DEFAULT '' COMMENT '合同主体单位，对应 jobcompanyId',
  `organization_id`       varchar(128)  NOT NULL DEFAULT '' COMMENT '所属部门编码，对应 organizationId（文档字段 organzationId）',
  `part_department_ids`   json                   DEFAULT NULL COMMENT '兼职部门编码数组，对应 partdeptId',
  `full_post_id`          varchar(128)  NOT NULL DEFAULT '' COMMENT '用户主岗编码，对应 fullpostId',
  `part_post_ids`         json                   DEFAULT NULL COMMENT '用户兼岗编码数组，对应 partpostId',
  `position_code`         varchar(128)  NOT NULL DEFAULT '' COMMENT '职位编码，对应 positioncode',
  `position_name`         varchar(255)  NOT NULL DEFAULT '' COMMENT '职位名称，对应 positionname',
  `job_code`              varchar(128)  NOT NULL DEFAULT '' COMMENT '新职务编码，对应 jobcode',
  `job_name`              varchar(255)  NOT NULL DEFAULT '' COMMENT '新职务名称，对应 jobname',
  `job_level_code`        varchar(128)  NOT NULL DEFAULT '' COMMENT '新职级编码，对应 joblevelcode',
  `job_level_name`        varchar(255)  NOT NULL DEFAULT '' COMMENT '新职级名称，对应 joblevel',
  `job_class_name`        varchar(255)  NOT NULL DEFAULT '' COMMENT '职类名称，对应 jobclassname',
  `person_attribute`      varchar(128)  NOT NULL DEFAULT '' COMMENT '人员属性，对应 jobglbdef62',
  `professional_title`    varchar(255)  NOT NULL DEFAULT '' COMMENT '职称，对应 zc',
  `nation`                varchar(128)  NOT NULL DEFAULT '' COMMENT '民族，对应 mz',
  `education`             varchar(128)  NOT NULL DEFAULT '' COMMENT '学历，对应 xl',
  `major`                 varchar(512)  NOT NULL DEFAULT '' COMMENT '专业，对应 zy',
  `degree`                varchar(128)  NOT NULL DEFAULT '' COMMENT '学位，对应 xw',

  `is_disabled`           tinyint(1)    NOT NULL DEFAULT 0 COMMENT '是否禁用：0-启用，1-禁用，对应 isDisabled',
  `is_deleted`            tinyint(1)    NOT NULL DEFAULT 0 COMMENT '源数据是否删除：0-否，1-是，对应 isDeleted',
  `user_exists`           tinyint(1)    NOT NULL DEFAULT 0 COMMENT '用户是否存在，对应 user_exists',
  `change_password_must`  tinyint(1)    NOT NULL DEFAULT 0 COMMENT '是否必须修改密码，对应 changePasswordMust',
  `change_password_at`    datetime(3)            DEFAULT NULL COMMENT '密码修改时间，对应 changePasswordAt',
  `wechat_work_id`        varchar(128)  NOT NULL DEFAULT '' COMMENT '企业微信用户ID，对应 weChatWorkId',
  `process_status`        varchar(32)   NOT NULL DEFAULT '' COMMENT '源数据处理状态，对应 zzProcessStatus',
  `user_jobs`             json                   DEFAULT NULL COMMENT '用户岗位关系数组，对应 userJobs',

  `nc_data`               longtext COMMENT 'NC原始数据，对应 ncdata；接口声明为 String',
  `nc_id`                 varchar(64)   NOT NULL DEFAULT '' COMMENT 'NC主键，对应 _AID',
  `bim_id`                varchar(128)  NOT NULL DEFAULT '' COMMENT 'BIM端主键，对应 _BID',
  `external_id`           varchar(128)  NOT NULL COMMENT '虚拟外部接口主键，对应 _ID',
  `bim_organization_id`   varchar(128)  NOT NULL DEFAULT '' COMMENT 'BIM端机构主键，对应 _BORGID',
  `nc_creation_time`      datetime(3)            DEFAULT NULL COMMENT 'NC数据创建时间，对应 creationtime',
  `source_create_at`      datetime(3)            DEFAULT NULL COMMENT '接口记录创建时间，对应 createAt',
  `source_update_at`      datetime(3)            DEFAULT NULL COMMENT '接口记录更新时间，对应 updateAt，增量同步游标',

  `create_time`           datetime(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3) COMMENT '中台记录创建时间',
  `modify_time`           datetime(3)   NOT NULL DEFAULT CURRENT_TIMESTAMP(3)
                                                 ON UPDATE CURRENT_TIMESTAMP(3) COMMENT '中台记录修改时间',
  `rec_status`            tinyint(4)    NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',

  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='IAM用户中台表';
