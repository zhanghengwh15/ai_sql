create index idx_taskconfigcode_dataid_status on task_retry_record (task_config_code, data_id, status);

create index idx_status_begintime_taskconfigcode on task_retry_record (status, begin_time, task_config_code);

create table `alarm_config_biz_relationship` (
    `id` bigint not null auto_increment comment '主键',
    `alarm_config_code` bigint not null default '0' comment '告警配置编号',
    `biz_code` bigint not null default '0' comment '任务|客户端编号',
    `biz_type` tinyint(1) not null default '1' comment '业务数据类型，1：任务，2：客户端',
    `site_code` bigint not null comment '站点编号',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_accode_btype` using BTREE (`alarm_config_code`, `biz_type`),
    key `idx_bcode_btype` using BTREE (`biz_code`, `biz_type`),
    key `idx_scode` using BTREE (`site_code`)
) comment '告警配置—任务|客户端关系表';

create table `alarm_config_user_relationship` (
    `id` bigint not null auto_increment comment '主键',
    `alarm_config_code` bigint not null default '0' comment '告警配置编号',
    `alarm_user_code` bigint not null default '0' comment '告警人编号',
    `site_code` bigint not null default '0' comment '站点编号',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_accode` using BTREE (`alarm_config_code`),
    key `idx_aucode` using BTREE (`alarm_user_code`),
    key `idx_scode` using BTREE (`site_code`)
) comment '告警配置—用户关系表';

create table `alarm_record` (
    `id` bigint not null auto_increment comment '主键',
    `alarm_record_code` bigint not null default '0' comment '告警记录编号',
    `site_code` bigint not null comment '站点编号',
    `alarm_config_code` bigint not null comment '告警配置编号',
    `notice_type` varchar(32) not null default ' ' comment '通知类型，execute_error: 执行异常通知; offline: 离线通知; offline_to_online: 离线后在线通知; high_frequency_error:高频失败通知; high_frequency_error_to_normal: 高频失败后恢复通知;',
    `biz_type` tinyint(1) not null default '1' comment '业务类型，1：任务，2：客户端',
    `biz_code` bigint default '0' comment '任务|客户端 编号',
    `record_content` text comment '告警明细',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_code` using BTREE (`alarm_record_code`),
    key `idx_acode_bcode_btype` using BTREE (`alarm_config_code`, `biz_code`, `biz_type`),
    key `idx_bcode_btype_acode` using BTREE (`biz_code`, `biz_type`, `alarm_config_code`)
) comment '告警记录表';

create table `alarm_silence_record` (
    `id` bigint not null auto_increment comment '主键',
    `silence_record_code` bigint not null default '0' comment '静默记录编号',
    `site_code` bigint not null comment '站点编号',
    `begin_time` datetime not null comment '静默开始时间',
    `end_time` datetime not null comment '静默结束时间',
    `silence_duration` bigint not null default '0' comment '静默时长(秒)',
    `biz_config_code` bigint default '0' comment '业务配置编号',
    `biz_type` tinyint(1) default null comment '业务类型，1:任务; 2:客户端',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_code` using BTREE (`silence_record_code`),
    key `idx_scode_tccode_time` using BTREE (`biz_config_code`, `biz_type`, `end_time`)
) comment '告警静默记录表';

alter table `alarm_config` modify column `type` tinyint(1) not null comment '告警类型，1：任务告警，2：客户端告警' after `name`,
    modify column `alarm_param` json null comment '告警参数' after `type`,
    add column `notice_rate` int not null comment '通知频率,  分钟/次' after `alarm_param`,
    add column `statistical_cycle` int not null comment '统计周期,  分钟' after `notice_rate`,
    modify column `trigger_scenes` json null comment '触发场景' after `statistical_cycle`,
    add index `idx_code` using BTREE (`code`);

alter table `dock_client` add column `ip_address` varchar(64) null default ' ' comment 'IP地址' after `modify_time`;

create table `alarm_user` (
    `id` bigint not null auto_increment comment '主键',
    `alarm_user_code` bigint not null default '0' comment '告警人编号',
    `site_code` bigint not null comment '站点编号',
    `user_name` varchar(32) not null default '' comment '用户名',
    `user_type` tinyint not null default '0' comment '用户类型, 1: 飞书群，2：企微，3：钉钉，4：小博制造APP',
    `notice_all` tinyint(1) not null default '0' comment '是否通知所有人, 0:不通知；1:通知；',
    `user_param` json default null comment '用户参数',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_code` using BTREE (`alarm_user_code`),
    key `idx_scode` using BTREE (`site_code`)
) comment '告警用户表';

alter table `alarm_config` modify column `type` tinyint(1) null default 1 comment '告警类型，1：任务告警，2：客户端告警' after `name`,
    modify column `notice_rate` int null default 30 comment '通知频率,  分钟/次' after `alarm_param`,
    modify column `statistical_cycle` int null default 30 comment '统计周期,  分钟' after `notice_rate`,
    modify column `trigger_scenes` json null comment '触发场景(废弃)' after `statistical_cycle`;

alter table `alarm_config` modify column `type` tinyint(1) null default 1 comment '告警类型，1：任务告警，2：客户端告警' after `name`,
    modify column `notice_rate` int null default 30 comment '通知频率,  分钟/次' after `alarm_param`,
    modify column `statistical_cycle` int null default 30 comment '统计周期,  分钟' after `notice_rate`,
    modify column `trigger_scenes` json null comment '触发场景(废弃)' after `statistical_cycle`;

create table `task_exception_record` (
    `id` bigint not null auto_increment comment '主键',
    `task_config_code` bigint default '0' comment '任务配置编码',
    `task_type` tinyint(1) default '1' comment '任务类型, 1：采集任务；2：计算任务；3：出仓任务；',
    `task_name` varchar(255) default null comment '任务名称',
    `task_record_code` bigint default '0' comment '任务记录编码',
    `data_id` bigint default '0' comment '数据id',
    `execute_status` tinyint(1) default '1' comment '任务记录执行状态, 0：待执行；1：执行中；2：执行成功；3：执行失败；4：取消；5：超时；',
    `execute_time` datetime default '1990-01-01 00:00:00' comment '任务执行时间',
    `request_id` varchar(64) default '' comment '客户端请求id',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    unique key `uk_tcc_dataid` using BTREE (`task_config_code`, `data_id`),
    key `idx_trcode` using BTREE (`task_record_code`),
    key `idx_ectime_tcc` using BTREE (`execute_time`, `task_config_code`)
) comment '任务异常记录表';

alter table `source_lock` modify column `source` varchar(64) not null default '' comment '锁住的资源' after `id`,
    modify column `request_id` varchar(64) not null default '' comment '请求id' after `unlock_at`,
    add index `idx_unlock_at` using BTREE (`unlock_at`),
    add index `idx_request_id` using BTREE (`request_id`);

create table `data_direct_sync_api_task` (
    `id` bigint not null auto_increment comment '主键',
    `site_code` bigint not null default '0' comment '站点编号',
    `name` varchar(64) not null default '' comment '任务名称',
    `biz_type` varchar(32) not null default '' comment '业务信息',
    `table_name` varchar(32) not null default '' comment '表名',
    `outbound_condition` varchar(255) not null default '' comment '出仓条件',
    `data_unique_field` varchar(32) not null default '' comment '数据唯一标识字段',
    `result_status_field` varchar(32) not null default '' comment '结果状态字段',
    `result_msg_field` varchar(32) not null default '' comment '结果描述字段',
    `order_by_field` varchar(32) not null default 'id' comment '排序字段',
    `limit_batch` int not null default '1' comment '每批次同步数量',
    `sync_process` varchar(32) not null default '0' comment '同步进度',
    `sync_target_url` varchar(255) not null default '' comment '同步目标接口url',
    `eid` varchar(32) not null default '' comment '企业eid',
    `sync_api_ak` varchar(64) not null default '' comment 'openapi的ak密钥',
    `sync_api_sk` varchar(64) not null default '' comment 'openapi的sk密钥',
    `enable_state` tinyint not null default '0' comment '是否启用',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`)
) comment '业务数据同步OpenAPI接口';

alter table `interface_info` modify column `header` varchar(1000) default '' comment '请求头header' after `request_type`;

alter table `task_retry_record` drop index `idx_status_begintime`,
    drop index `idx_task_record_code`,
    drop index `idx_taskconfigcode_dataid_status`,
    add index `idx_tccode_status_data_id` using BTREE (`task_config_code`, `status`, `data_id`);

create table `data_source_token_record` (
    `id` bigint not null auto_increment comment '主键',
    `token_record_code` bigint not null default '0' comment '数据源token记录编号',
    `site_code` bigint not null default '0' comment '站点编号',
    `data_source_code` bigint not null default '0' comment '数据源编号',
    `token_value` varchar(1000) not null default '' comment 'token值',
    `refresh_token_value` varchar(1000) not null default '' comment 'refreshToken值',
    `token_effective_time` bigint not null default '0' comment 'token有效期(分钟)',
    `token_expiration_date` datetime not null default '2020-01-01 00:00:00' comment 'token过期时间',
    `token_status` tinyint not null default '0' comment 'token状态，0-预生成；1-生成中；2-成功；3-失败；4-已失效；',
    `extends_data` text comment '扩展信息字段',
    `task_record_code` bigint not null default '0' comment '执行记录code',
    `remark` varchar(500) default '' comment '备注',
    `rec_status` tinyint(1) not null default '1' comment '逻辑删除(0:删除，1:有效)',
    `create_by` bigint not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_code_status` using BTREE (`data_source_code`, `token_status`),
    key `idx_task_record_code` using BTREE (`task_record_code`),
    key `idx_status_expire` using BTREE (`token_status`, `token_expiration_date`),
    key `idx_site_code` using BTREE (`site_code`)
) comment '数据源token记录';

alter table area modify column `json` LONGTEXT comment '配置json';

alter table site add column private_key varchar(64) not null default '' comment '站点私钥';

alter table `task_exception_record` add column `priority_level` TINYINT null default 0 comment '任务优先级，级别越大越先执行',
    add column `execute_client_code` BIGINT null default 0 comment '执行客户端编码';

alter table `task_exception_record` add index `idx_status_client_type_priority_time` (`execute_status` asc, `task_record_code`, `task_type`, `priority_level` desc, `create_time` asc);

alter table `task_config` add column `priority_level` TINYINT not null default 0 comment '任务优先级，级别越大越先执行';

alter table data_dictionary add column cloud_platform_retry TINYINT not null default 0 comment '云平台重试 0 否，1 是';

alter table `dock_client` add index `idx_access_key` using BTREE (`access_key`, `rec_status`);

alter table `alarm_record` drop index `idx_acode_bcode_btype`,
    add index `idx_acode_bcode_btype_ctime` (`alarm_config_code`, `biz_code`, `biz_type`, `create_time`);

alter table `field` add index `idx_platform_uuid_status` (`platform_uuid`, `uuid`, `rec_status`);

create index `idx_platform_table_status_time` on `field_area` (platform_uuid, table_model_uuid, rec_status, create_time);

alter table `area` add index `idx_platform_uuid_code` (`platform_uuid`, `code`, `rec_status`);

alter table `field_area` add index `idx_platform_uuid_alias_type` (`platform_uuid`, `alias`, `type`, `rec_status`, `create_time`, `area_uuid`);

alter table data_dictionary add column support_biz_maintain TINYINT not null default 0 comment '是否支持业务维护，0：不支持；1：支持',
    add column biz_maintain_config TEXT null comment '业务维护配置';

create table `data_dictionary_data_audit` (
    `id` bigint not null auto_increment comment '主键ID',
    `site_code` bigint default null comment '站点编码',
    `data_dictionary_code` bigint not null comment '数据字典编码',
    `physical_name` varchar(128) not null comment '业务物理表名',
    `row_id` bigint not null comment '业务数据主键ID',
    `before_data` json not null comment '修改前整行快照JSON',
    `after_data` json not null comment '修改后整行快照JSON',
    `changed_fields` json not null comment '变更字段JSON数组',
    `change_reason` varchar(512) not null comment '修改/回滚原因',
    `operator_id` bigint default null comment '操作人ID',
    `operate_time` datetime not null comment '操作时间',
    `operation_type` tinyint not null default 1 comment '操作类型：1编辑，2回滚',
    `rollback_status` tinyint not null default 0 comment '回滚状态：0未回滚，1已回滚，2回滚失败',
    `rollback_audit_id` bigint default null comment '回滚产生的审计记录ID',
    `rollback_reason` varchar(512) default null comment '回滚原因',
    `rollback_time` datetime default null comment '回滚时间',
    `rec_status` tinyint not null default 1 comment '逻辑删除状态：0无效，1有效',
    `create_by` bigint default null comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint default null comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    key `idx_ddda_dict_row_time` (`data_dictionary_code`, `row_id`, `operate_time`),
    key `idx_ddda_physical_row_time` (`physical_name`, `row_id`, `operate_time`),
    key `idx_ddda_operator_time` (`operator_id`, `operate_time`)
) engine = InnoDB charset = utf8mb4 comment '数据字典业务数据审计记录';

alter table `token_info` modify column `token` varchar(1000) not null default '' comment '令牌';

create table `operate_log` (
    `id` bigint(20) unsigned not null auto_increment comment '主键ID',
    `biz_type` varchar(64) not null default '' comment '业务类型',
    `user_id` bigint(20) unsigned not null default '0' comment '操作用户ID',
    `username` varchar(128) not null default '' comment '操作用户名',
    `client_ip` varchar(64) not null default '' comment '客户端IP',
    `user_agent` varchar(512) not null default '' comment '浏览器UA',
    `result` varchar(32) not null default '' comment '操作结果',
    `fail_reason` varchar(512) not null default '' comment '失败原因',
    `extra` varchar(1000) not null default '' comment '扩展字段',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    `rec_status` tinyint(4) not null default '1' comment '记录状态：1-有效，0-删除',
    `create_by` bigint(20) unsigned not null default '0' comment '创建人ID',
    `modify_by` bigint(20) unsigned not null default '0' comment '修改人ID',
    primary key (`id`),
    key `idx_user_id` (`user_id`),
    key `idx_biz_type_create_time` (`biz_type`, `create_time`)
) comment '操作行为日志';

create table `user_column_config` (
    `id` bigint(20) unsigned not null auto_increment comment '主键ID',
    `dict_id` bigint(20) unsigned not null default '0' comment '数据字典ID',
    `user_id` bigint(20) unsigned not null default '0' comment '用户ID',
    `column_config` json not null comment '列配置信息（JSON数组）',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    `rec_status` tinyint(4) not null default '1' comment '记录状态：1-有效，0-删除',
    `create_by` bigint(20) unsigned not null default '0' comment '创建人ID',
    `modify_by` bigint(20) unsigned not null default '0' comment '修改人ID',
    primary key (`id`),
    unique key `uk_dict_user` (`dict_id`, `user_id`)
) comment '用户数据字典浏览列配置表';

alter table `open_api_info` add column `task_param` json comment '任务扩展配置JSON，开放接口数据更新配置存储于 update 节点' after `fields_mapping`;

create table `data_dictionary_data_export_record` (
    `id` bigint(20) unsigned not null auto_increment comment '主键',
    `task_code` bigint(20) unsigned not null comment '导出任务编号',
    `data_dictionary_code` bigint(20) unsigned not null comment '数据词典编号',
    `site_code` bigint(20) unsigned not null comment '站点编号',
    `user_id` bigint(20) unsigned not null comment '创建用户ID',
    `dictionary_cn_name` varchar(100) not null default '' comment '数据词典中文名快照',
    `physical_name` varchar(100) not null default '' comment '业务物理表名快照',
    `file_name` varchar(255) not null default '' comment '导出文件名',
    `file_path` varchar(500) not null default '' comment '对象存储内部路径',
    `file_size` bigint(20) unsigned not null default '0' comment '文件字节数',
    `exported_row_count` bigint(20) unsigned not null default '0' comment '实际导出行数',
    `request_snapshot` text null comment '可信导出请求快照',
    `request_hash` varchar(64) not null default '' comment '规范化请求SHA-256摘要',
    `active_key` varchar(160) default null comment '用户活动任务唯一键，终态为空',
    `export_status` tinyint(3) unsigned not null default '0' comment '0待执行 1处理中 2成功 3失败 4已过期 5已取消',
    `cancel_requested` tinyint(3) unsigned not null default '0' comment '是否请求取消：0否 1是',
    `heartbeat_time` datetime not null default '1970-01-01 08:00:00' comment '任务最近心跳时间',
    `error_code` varchar(100) not null default '' comment '稳定错误码',
    `error_params` varchar(1000) not null default '' comment '国际化安全参数JSON',
    `expire_time` datetime not null default '1970-01-01 08:00:00' comment '文件过期时间',
    `rec_status` tinyint(3) unsigned not null default '1' comment '记录状态：0删除 1有效',
    `create_by` bigint(20) unsigned not null default '0' comment '创建人',
    `create_time` datetime not null default current_timestamp comment '创建时间',
    `modify_by` bigint(20) unsigned not null default '0' comment '修改人',
    `modify_time` datetime not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    unique key `uk_task_code` (`task_code`),
    unique key `uk_active_key` (`active_key`),
    key `idx_user_site_dict_time` (`user_id`, `site_code`, `data_dictionary_code`, `create_time`),
    key `idx_export_status_time` (`export_status`, `heartbeat_time`, `create_time`),
    key `idx_export_status_expire_time` (`export_status`, `expire_time`)
) engine = InnoDB comment '数据词典业务数据导出记录';

create table `data_sync_task` (
    `id` BIGINT not null auto_increment comment '主键',
    `task_code` BIGINT not null comment '任务编码',
    `task_type` TINYINT not null comment '任务类型：0同步包、1导出、2导入',
    `source_site_code` BIGINT default null comment '源站点编码',
    `target_site_code` BIGINT default null comment '目标站点编码',
    `bundle_id` VARCHAR(128) not null comment '同步包标识',
    `bundle_path` VARCHAR(512) default null comment '对象存储路径',
    `plan_hash` VARCHAR(128) default null comment '计划哈希',
    `request_snapshot` JSON comment '脱敏后的请求 JSON 快照',
    `confirm_token_hash` VARCHAR(128) default null comment '确认令牌哈希',
    `confirm_expire_time` DATETIME(3) default null comment '确认令牌过期时间',
    `idempotency_key` VARCHAR(128) default null comment '导入幂等键',
    `scope_lock_key` VARCHAR(128) default null comment '导入范围互斥键，仅待确认或执行中保留',
    `task_status` TINYINT not null comment '任务状态：0待处理、1执行中、2待确认、3成功、4失败、5已取消、6已过期',
    `total_rows` BIGINT not null default 0 comment '总行数',
    `completed_rows` BIGINT not null default 0 comment '已完成行数',
    `total_parts` BIGINT not null default 0 comment '总分片数',
    `completed_parts` BIGINT not null default 0 comment '已完成分片数',
    `cancel_requested` TINYINT not null default 0 comment '是否请求取消：0否、1是',
    `heartbeat_time` DATETIME(3) default null comment '执行心跳时间',
    `error_code` VARCHAR(128) default null comment '错误码',
    `error_params` VARCHAR(1024) default null comment '错误参数',
    `expire_time` DATETIME(3) not null comment '任务或包过期时间',
    `rec_status` TINYINT not null default 1 comment '记录状态',
    `create_by` BIGINT default null comment '创建人',
    `create_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) comment '创建时间',
    `modify_by` BIGINT default null comment '修改人',
    `modify_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) on update CURRENT_TIMESTAMP(3) comment '修改时间',
    primary key (`id`),
    unique key `uk_sync_task_scope_lock` (`scope_lock_key`)
) comment '跨环境数据同步任务';

create table `data_sync_part_checkpoint` (
    `id` BIGINT not null auto_increment comment '主键',
    `task_code` BIGINT not null comment '任务编码',
    `physical_table_name` VARCHAR(128) not null comment '物理表名',
    `part_name` VARCHAR(512) not null comment '包内分片路径',
    `part_row_count` BIGINT not null default 0 comment '分片行数',
    `part_status` TINYINT not null comment '分片状态：0待处理、1执行中、2成功、3失败、4已取消',
    `last_error` VARCHAR(1024) default null comment '最后错误摘要',
    `updated_time` DATETIME(3) not null comment '状态更新时间',
    `rec_status` TINYINT not null default 1 comment '记录状态',
    `create_by` BIGINT default null comment '创建人',
    `create_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) comment '创建时间',
    `modify_by` BIGINT default null comment '修改人',
    `modify_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) on update CURRENT_TIMESTAMP(3) comment '修改时间',
    primary key (`id`),
    unique key `uk_data_sync_checkpoint_task_part` (`task_code`, `physical_table_name`, `part_name`)
) comment '跨环境数据同步分片检查点';

create table `data_sync_audit_record` (
    `id` BIGINT not null auto_increment comment '主键',
    `task_code` BIGINT not null comment '任务编码',
    `request_id` VARCHAR(128) default null comment '请求标识',
    `operator_id` BIGINT default null comment '操作者',
    `source_site_code` BIGINT default null comment '源站点编码',
    `target_site_code` BIGINT default null comment '目标站点编码',
    `table_summary` VARCHAR(2048) default null comment '表清单摘要',
    `condition_summary` VARCHAR(2048) default null comment '条件摘要',
    `result` VARCHAR(32) not null comment '执行结果',
    `error_code` VARCHAR(128) default null comment '错误码',
    `rec_status` TINYINT not null default 1 comment '记录状态',
    `create_by` BIGINT default null comment '创建人',
    `create_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) comment '创建时间',
    `modify_by` BIGINT default null comment '修改人',
    `modify_time` DATETIME(3) not null default CURRENT_TIMESTAMP(3) on update CURRENT_TIMESTAMP(3) comment '修改时间',
    primary key (`id`)
) comment '跨环境数据同步审计记录';

create table if not exists `task_config_ai_apply_record` (
    `id` BIGINT(20) unsigned not null auto_increment comment '主键ID',
    `request_id` VARCHAR(64) not null comment '客户端幂等请求UUID',
    `request_digest` CHAR(64) not null comment '规范化请求内容的SHA-256摘要',
    `operation` VARCHAR(16) not null comment '写入操作：CREATE、UPDATE',
    `site_code` BIGINT(20) unsigned not null comment '目标站点编码',
    `task_config_id` BIGINT(20) unsigned null comment '成功写入后的任务配置主键ID',
    `task_config_code` BIGINT(20) unsigned null comment '成功写入后的任务配置业务编码',
    `apply_status` VARCHAR(16) not null default 'PROCESSING' comment '处理状态：PROCESSING、APPLIED、REJECTED、CONFLICT、FAILED',
    `response_snapshot` MEDIUMTEXT null comment '脱敏响应快照；到期清理，仅用于幂等结果回放',
    `error_stage` VARCHAR(16) null comment '失败阶段：AUTH、IDEMPOTENCY、CONFIG、SCHEDULE、ENGINE、STATIC、APPLY、READ_BACK',
    `error_code` VARCHAR(128) null comment '稳定业务错误码',
    `cleanup_status` VARCHAR(16) not null default 'RETAINED' comment '快照清理状态：RETAINED、CLEANUP_PENDING、CLEANED',
    `snapshot_expire_time` DATETIME null comment '响应快照过期时间；无快照时为空',
    `rec_status` TINYINT(4) not null default 1 comment '记录状态：1-有效，0-删除',
    `create_by` BIGINT(20) unsigned not null default 0 comment '创建人ID',
    `create_time` DATETIME not null default current_timestamp comment '创建时间',
    `modify_by` BIGINT(20) unsigned not null default 0 comment '修改人ID',
    `modify_time` DATETIME not null default current_timestamp on update current_timestamp comment '修改时间',
    primary key (`id`),
    unique key `uk_site_code_request_id` (`site_code`, `request_id`),
    key `idx_snapshot_expire_time` (`snapshot_expire_time`)
) engine = InnoDB comment 'AI计算任务验证写入幂等审计记录';
