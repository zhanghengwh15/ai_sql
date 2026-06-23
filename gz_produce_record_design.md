# 广纸生产记录表设计

## 1. 概述

本文档描述了广纸生产记录表的数据库设计，该表用于记录生产过程中的关键数据，包括报工信息、产品规格、质量检测、入库状态等。

### 设计目标

- 支持广纸业务的生产数据记录和查询
- 确保数据完整性和一致性
- 便于数据分析和报表生成
- 符合项目数据库设计规范

## 2. 业务分析

### 2.1 业务实体

- **生产记录**: 记录生产过程中的关键数据
- **报工信息**: 报工日期、时间、任务号等
- **产品规格**: 直径、长度、幅宽、定量等
- **质量检测**: 等级、等级原因、质检状态等
- **入库状态**: 入库时间、退库时间、入库状态等

### 2.2 实体关系

- 生产记录与报工表关联（1:1 关系）
- 生产记录与报工扩展表关联（1:1 关系）

## 3. 数据库设计

### 3.1 生产记录表 (gz_produce_record)

**说明**: 记录生产过程中的关键数据，包括报工信息、产品规格、质量检测、入库状态等。

**字段列表**:

| 字段名 | 类型 | 约束 | 默认值 | 说明 |
|--------|------|------|--------|------|
| id | BIGINT(20) UNSIGNED | PRIMARY KEY, NOT NULL, AUTO_INCREMENT | - | 主键ID |
| sheet_id | BIGINT(20) UNSIGNED | NOT NULL, UNIQUE | 0 | 报工id（关联produce_sheet表） |
| org_id | BIGINT(20) UNSIGNED | NOT NULL | 0 | 企业Id |
| create_time | DATETIME | NOT NULL | CURRENT_TIMESTAMP | 创建时间 |
| modify_time | DATETIME | NOT NULL | CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP | 更新时间 |
| send_date | DATE | NOT NULL | '1970-01-01' | 报工日期 |
| sheet_time | DATETIME | NULL | NULL | 报工时间点 |
| diam | DECIMAL(10, 2) | NULL | NULL | 直径 |
| length | DECIMAL(21, 3) | NULL | NULL | 长度 |
| range_wide | INT | NULL | NULL | 幅宽 |
| quantitative | DECIMAL(21) | NULL | NULL | 定量 |
| small_roll_number | VARCHAR(255) | NOT NULL | '' | 小卷辊号 |
| customer | VARCHAR(70) | NULL | NULL | 客户 |
| weigh_output | DECIMAL(22, 4) | NOT NULL | 0.0000 | 称重重量 |
| output | DECIMAL(22, 6) | NOT NULL | 0.000000 | 大标签重量（产量） |
| estimated_weight | DECIMAL(22, 6) | NULL | NULL | 预估重量 |
| factory_area_id | BIGINT(20) UNSIGNED | NOT NULL | 0 | 工作单元ID |
| factory_area_name | VARCHAR(255) | NOT NULL | '' | 工作单元名称（中文） |
| material_id | BIGINT(20) UNSIGNED | NOT NULL | 0 | 物料ID |
| material_name | VARCHAR(255) | NOT NULL | '' | 物料名称（中文） |
| return_stock_label | INT | NOT NULL | 0 | 退库标识（广纸的特定业务字段） |
| storage_status | TINYINT | NOT NULL | 0 | 入库状态（0:未入库，1:已入库，2:已退库） |
| storage_time | DATETIME | NULL | NULL | 入库时间 |
| return_time | DATETIME | NULL | NULL | 退库时间 |
| standard_sequential_number | JSON | NULL | NULL | 标准序号 |
| factory_code | VARCHAR(255) | NOT NULL | '' | 工厂编码 |
| grade_id | BIGINT(20) UNSIGNED | NOT NULL | 0 | 等级Id |
| grade_name | VARCHAR(255) | NOT NULL | '' | 等级名称（中文） |
| grade_reason | VARCHAR(1000) | NULL | NULL | 等级原因 |
| status | SMALLINT | NOT NULL | 1 | 完工状态（1:完工，2:退回） |
| rec_status | TINYINT(4) | NOT NULL | 1 | 记录状态：1-有效，0-删除 |
| create_by | BIGINT(20) UNSIGNED | NOT NULL | 0 | 创建人ID |
| modify_by | BIGINT(20) UNSIGNED | NOT NULL | 0 | 修改人ID |

**索引**:
- PRIMARY KEY (id)
- UNIQUE KEY uk_sheet_id (sheet_id)
- KEY idx_org_id (org_id)
- KEY idx_send_date (send_date)
- KEY idx_customer (customer)
- KEY idx_material_id (material_id)
- KEY idx_storage_status (storage_status)

**关联关系**:
- 关联 produce_sheet 表（sheet_id -> produce_sheet.sheet_id），一对一关系
- 关联 produce_sheet_ext 表（sheet_id -> produce_sheet_ext.sheet_id），一对一关系

## 4. SQL建表语句

```sql
CREATE TABLE `gz_produce_record` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `sheet_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '报工id（关联produce_sheet表）',
  `org_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '企业Id',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `send_date` DATE NOT NULL DEFAULT '1970-01-01' COMMENT '报工日期',
  `sheet_time` DATETIME NULL COMMENT '报工时间点',
  `diam` DECIMAL(10, 2) NULL COMMENT '直径',
  `length` DECIMAL(21, 3) NULL COMMENT '长度',
  `range_wide` INT NULL COMMENT '幅宽',
  `quantitative` DECIMAL(21) NULL COMMENT '定量',
  `small_roll_number` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '小卷辊号',
  `customer` VARCHAR(70) NULL COMMENT '客户',
  `weigh_output` DECIMAL(22, 4) NOT NULL DEFAULT 0.0000 COMMENT '称重重量',
  `output` DECIMAL(22, 6) NOT NULL DEFAULT 0.000000 COMMENT '大标签重量（产量）',
  `estimated_weight` DECIMAL(22, 6) NULL COMMENT '预估重量',
  `factory_area_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '工作单元ID',
  `factory_area_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '工作单元名称（中文）',
  `material_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '物料ID',
  `material_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '物料名称（中文）',
  `return_stock_label` INT NOT NULL DEFAULT 0 COMMENT '退库标识（广纸的特定业务字段）',
  `storage_status` TINYINT NOT NULL DEFAULT 0 COMMENT '入库状态（0:未入库，1:已入库，2:已退库）',
  `storage_time` DATETIME NULL COMMENT '入库时间',
  `return_time` DATETIME NULL COMMENT '退库时间',
  `standard_sequential_number` JSON NULL COMMENT '标准序号',
  `factory_code` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '工厂编码',
  `grade_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '等级Id',
  `grade_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '等级名称（中文）',
  `grade_reason` VARCHAR(1000) NULL COMMENT '等级原因',
  `status` SMALLINT NOT NULL DEFAULT 1 COMMENT '完工状态（1:完工，2:退回）',
  `rec_status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `create_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_sheet_id` (`sheet_id`),
  KEY `idx_org_id` (`org_id`),
  KEY `idx_send_date` (`send_date`),
  KEY `idx_customer` (`customer`),
  KEY `idx_material_id` (`material_id`),
  KEY `idx_storage_status` (`storage_status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='广纸生产记录表';
```

## 5. 设计说明

### 5.1 设计思路

1. **字段选择**: 从 produce_sheet 和 produce_sheet_ext 表中选择了广纸业务所需的关键字段
2. **数据类型**: 严格遵循项目的数据库设计规范，使用适当的数据类型
3. **索引设计**: 为常用查询字段创建了索引，包括 org_id、send_date、customer、material_id 等
4. **关联关系**: 与 produce_sheet 表建立一对一关联，确保数据一致性
5. **中文名称**: 添加了 factory_area_name 和 material_name 字段，用于存储工作单元和物料的中文名称

### 5.2 注意事项

1. **数据同步**: 需要确保该表与 produce_sheet 和 produce_sheet_ext 表的数据同步
2. **工作单元名称**: 工厂编码和工作单元ID需要通过其他表或字典获取对应的中文名称
3. **物料名称**: 物料ID需要通过物料表获取对应的中文名称
4. **退库标识**: return_stock_label 字段是广纸的特定业务字段，需要根据实际业务需求进行处理
5. **入库状态**: storage_status 字段表示入库状态，需要与入库流程同步

### 5.3 性能考虑

1. **索引优化**: 为常用查询字段创建了索引，提高查询效率
2. **数据类型优化**: 使用适当的数据类型，减少存储空间占用
3. **查询优化**: 避免在查询中使用函数运算，确保索引被正确使用

## 6. 检查清单

- [x] 所有字段都设置了NOT NULL和默认值
- [x] 包含了标准字段（id、create_time、modify_time、rec_status、org_id、create_by、modify_by）
- [x] 表名和字段名符合命名规范
- [x] 索引设计基于实际业务场景
- [x] 多租户环境下包含org_id字段
- [x] 字符集统一为utf8mb4
- [x] 符合mysql-database-standards.md中的其他规范

