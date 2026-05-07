-- 纸卷信息表
-- 说明：存储纸卷的详细信息，包括包装状态、尺寸、标签、客户信息等
-- 创建时间：2026-02-01

CREATE TABLE `paper_roll_info` (
  -- 主键和标准字段
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  
  -- 纸卷基本信息
  `roll_unique_code` varchar(16) NOT NULL DEFAULT '' COMMENT '纸卷唯一编号',
  `roll_tracking_no` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '纸卷跟踪号',
  `packaging_status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷包装状态：0-cull，1-good，2-hold',
  `sequence_no` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '顺序号（自动增长）',
  
  -- 订单信息
  `order_no` varchar(30) NOT NULL DEFAULT '' COMMENT '订单编号',
  `order_item_no` varchar(20) NOT NULL DEFAULT '' COMMENT '订单项目号',
  
  -- 纸卷尺寸信息
  `roll_width` int(11) NOT NULL DEFAULT 0 COMMENT '纸卷宽度（单位：mm）',
  `roll_diameter` int(11) NOT NULL DEFAULT 0 COMMENT '纸卷直径（单位：mm）',
  `roll_length` int(11) NOT NULL DEFAULT 0 COMMENT '纸卷长度（单位：mm）',
  `core_diameter` int(11) NOT NULL DEFAULT 0 COMMENT '纸筒芯直径（单位：mm）',
  `diameter_tolerance` int(11) NOT NULL DEFAULT 0 COMMENT '直径公差（单位：mm）',
  `width_tolerance` int(11) NOT NULL DEFAULT 0 COMMENT '宽度公差（单位：mm）',
  
  -- 重量信息
  `calculated_weight` int(11) NOT NULL DEFAULT 0 COMMENT '计算重量（单位：g）',
  `weight_tolerance` int(11) NOT NULL DEFAULT 0 COMMENT '重量公差（单位：g）',
  `core_weight` int(11) NOT NULL DEFAULT 0 COMMENT '纸芯重量（单位：g）',
  `packaging_weight_sum` int(11) NOT NULL DEFAULT 0 COMMENT '包装纸和封头纸芯重量和（单位：g）',
  
  -- 包装信息
  `packaging_layers` int(11) NOT NULL DEFAULT 0 COMMENT '包装圈层数（21=2.1层）',
  `is_bundled` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷成捆：0-不打捆，1-包装',
  `is_packaged` tinyint(4) NOT NULL DEFAULT 0 COMMENT '是否包装：0-不包装，1-包装',
  `packaging_paper_type` tinyint(4) NOT NULL DEFAULT 1 COMMENT '包装纸种类（缺省为1）',
  
  -- 封头信息
  `inner_head_1` tinyint(4) NOT NULL DEFAULT 0 COMMENT '内封头1：0-无，1-有',
  `inner_head_2` tinyint(4) NOT NULL DEFAULT 0 COMMENT '内封头2：0-无，1-有',
  `outer_head_1` tinyint(4) NOT NULL DEFAULT 0 COMMENT '外封头1：0-无，1-有',
  `outer_head_2` tinyint(4) NOT NULL DEFAULT 0 COMMENT '外封头2：0-无，1-有',
  
  -- 标签信息
  `body_label_count` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷身标签数：0-无，1-一个标签',
  `head_label_count` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷头标签数：0-无，1-一个标签',
  `body_label_paper_box` tinyint(4) NOT NULL DEFAULT 1 COMMENT '纸卷身标签打印纸盒选择：1-英文，2-绿色中文，3-黑色中文',
  `head_label_paper_box` tinyint(4) NOT NULL DEFAULT 1 COMMENT '纸卷头标签打印纸盒选择：1-英文，2-绿色中文，3-黑色中文',
  
  -- 其他信息
  `next_destination` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷下一目的地：0-楼面，1-仓库',
  `is_inkjet_engraved` tinyint(4) NOT NULL DEFAULT 0 COMMENT '纸卷喷墨刻字：0-不喷墨，1-喷墨',
  `is_processed` tinyint(4) NOT NULL DEFAULT 0 COMMENT '是否处理：0-未处理，1-已处理',
  
  -- 客户信息
  `customer_no` varchar(50) NOT NULL DEFAULT '' COMMENT '客户编号',
  `customer_name` varchar(50) NOT NULL DEFAULT '' COMMENT '客户名称',
  
  -- 质量标准信息
  `standard_no` varchar(50) NOT NULL DEFAULT '' COMMENT '标准编号（如：GB/T 1910-2006）',
  `basis_weight` int(11) NOT NULL DEFAULT 0 COMMENT '定量（单位：g/m²）',
  `quality_grade_desc` varchar(16) NOT NULL DEFAULT '' COMMENT '质量等级描述（如：优等）',
  `quality_grade_code` varchar(3) NOT NULL DEFAULT '' COMMENT '质量等级编码（如：260）',
  `production_date` varchar(10) NOT NULL DEFAULT '' COMMENT '生产日期',
  `record_create_date` datetime NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '记录创建日期',
  
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='纸卷信息表';
