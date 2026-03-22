-- 用户技能表建表语句
-- 说明：存储用户技能信息，包括用户、岗位、技能、获得日期和备注
-- 注意：请根据实际项目修改表名前缀（如：yt_user_skill）

CREATE TABLE `user_skill` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '用户ID（关联用户表，显示格式：用户名:昵称）',
  `position_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '岗位ID（关联岗位表，显示岗位名称）',
  `skill` varchar(512) NOT NULL DEFAULT '' COMMENT '技能描述',
  `acquire_date` datetime NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '获得日期',
  `remark` varchar(1024) NOT NULL DEFAULT '' COMMENT '备注',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户技能表';

-- 后续根据业务查询需求添加索引（通过ALTER TABLE添加）
-- 示例索引（根据实际查询场景选择添加）：
-- 1. 按机构+用户查询技能列表
-- ALTER TABLE `user_skill` ADD KEY `idx_org_user_id` (`org_id`, `user_id`);
--
-- 2. 按机构+岗位查询技能列表
-- ALTER TABLE `user_skill` ADD KEY `idx_org_position_id` (`org_id`, `position_id`);
--
-- 3. 按机构+用户+岗位查询
-- ALTER TABLE `user_skill` ADD KEY `idx_org_user_position` (`org_id`, `user_id`, `position_id`);
--
-- 4. 按机构+获得日期查询
-- ALTER TABLE `user_skill` ADD KEY `idx_org_acquire_date` (`org_id`, `acquire_date`);
