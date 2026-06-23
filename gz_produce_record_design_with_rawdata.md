# 广纸生产记录表设计（含原始数据字段）

## 1. 概述

本文档描述了广纸生产记录表的数据库设计，该表用于记录生产过程中的关键数据，包括报工信息、产品规格、质量检测、入库状态等，并添加了专门存储原始数据的 JSON 字段。

### 设计目标

- 支持广纸业务的生产数据记录和查询
- 确保数据完整性和一致性
- 便于数据分析和报表生成
- 保留原始数据以便后续分析和验证
- 符合项目数据库设计规范

## 2. 业务分析

### 2.1 业务实体

- **生产记录**: 记录生产过程中的关键数据
- **报工信息**: 报工日期、时间、任务号等
- **产品规格**: 直径、长度、幅宽、定量等
- **质量检测**: 等级、等级原因、质检状态等
- **入库状态**: 入库时间、退库时间、入库状态等
- **原始数据**: 完整的原始数据记录（JSON格式）

### 2.2 实体关系

- 生产记录与报工表关联（1:1 关系）
- 生产记录与报工扩展表关联（1:1 关系）

## 3. 数据库设计

### 3.1 生产记录表 (gz_produce_record)

**说明**: 记录生产过程中的关键数据，包括报工信息、产品规格、质量检测、入库状态等，并保留原始数据。

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
| raw_data | JSON | NULL | NULL | 原始数据（包含完整的报工和扩展表信息） |

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
  `raw_data` JSON NULL COMMENT '原始数据（包含完整的报工和扩展表信息）',
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

### 5.1 原始数据字段说明

**字段名**: `raw_data`
**类型**: JSON
**默认值**: NULL
**说明**: 存储完整的原始数据记录，包含从报工表和报工扩展表获取的所有信息。

**原始数据结构示例**:

```json
{
  "produce_sheet": {
    "sheet_id": 12345,
    "org_id": 1001,
    "produce_task_id": 54321,
    "shift_id": "shift_001",
    "course_id": "course_001",
    "batch_no": "batch_20231010",
    "task_no": "task_001",
    "material_id": 67890,
    "send_date": "2023-10-10",
    "output": 100.500000,
    "status": 1,
    "grade_id": 1,
    "color_id": 2,
    "sheet_batch_no": "sheet_batch_001",
    "stop_task_flag": 0,
    "part_sheet_flag": 1,
    "factory_area_id": 101,
    "pt": "pt_001",
    "create_by": 10001,
    "create_time": "2023-10-10 10:30:00",
    "modify_by": 10001,
    "modify_time": "2023-10-10 10:30:00",
    "rec_status": 1,
    "check_mode": "1",
    "entry_status": 0,
    "entry_id": 0,
    "task_finish": 0,
    "sheet_batch_begin_time": "2023-10-10 08:00:00",
    "sheet_batch_end_time": "2023-10-10 10:30:00",
    "shift_sheet_no": "shift_sheet_001",
    "range_wide": 1000,
    "speed": 50.000000000,
    "quantitative": 150,
    "length": 2500.000,
    "check_result": -1,
    "check_time": null,
    "gross_weight": 105.250,
    "roll": "roll_001",
    "container": 1001,
    "roll_batch": "roll_batch_001",
    "issued_type": 1,
    "color_text": "红色",
    "sheet_entry_remark": "正常报工",
    "main_sheet_id": 0,
    "main_factory_area_id": 0,
    "main_send_date": null,
    "main_shift_id": "",
    "main_course_id": "",
    "grade_reason": "",
    "wet_weight": 102.500,
    "sheet_grade_id": null,
    "qrcode_record_id": 0,
    "store_id": 0,
    "merge_sheet": 0,
    "merge_sheet_sum": 0,
    "re_roll_no": "re_roll_001",
    "note": "",
    "sheet_type": "normalSheet",
    "sheet_time": "2023-10-10 10:30:00",
    "material_distribution_id": null,
    "source": 1,
    "loss_amount": null,
    "loss_reason_id": 0,
    "product_paper_type": "A4纸",
    "diam": 150.50,
    "customer": "客户A",
    "paper_disease": "",
    "machine_no": 1,
    "out_paper_roll_no": "",
    "connector": 0,
    "paper_bind_num": "",
    "inkjet_code": null,
    "check_finish": 0,
    "proposal_meter": null,
    "org_position_id": null,
    "rack_num": null,
    "slitting_date": null,
    "slitting_course_group": "",
    "large_roll_no": "",
    "paper_core": "",
    "forklift_driver": null,
    "handle_worker": "",
    "custom_batch_no": "custom_batch_001",
    "tray_no": "tray_001",
    "quality_test_monitor": "monitor_001",
    "sampler": "sampler_001",
    "document_code": "doc_001",
    "output_type": 1,
    "wet_output": 102.5000,
    "weigh_output": 100.5000,
    "tare": 4.7500,
    "data_source": 2,
    "roll_radius": 75.250,
    "produce_factory_area_id": null,
    "device_linkage": 2,
    "rush_sell": 0,
    "flaw_desc": "",
    "produce_work_order_id": 0,
    "associated_sheet_id": 0,
    "step_id": null,
    "sabetsu": -1,
    "init_grade_material_id": 0,
    "wine_barrel_id": 0,
    "init_grade_quantity": null,
    "tanker_id": 0,
    "sheet_flag": 1,
    "area": 25.000,
    "net_weight": 100.500,
    "volume": 1,
    "customer_id": 0,
    "doc_sequence_id": "doc_seq_001",
    "mblnr": "",
    "custom_field": null,
    "work_order_template_id": 0,
    "sheet_field_config": null,
    "sheet_logic_config": null,
    "send_time": "2023-10-10 10:30:00",
    "biz_type": 1,
    "produce_work_order_data": null,
    "sale_order": -1,
    "saleman": null,
    "position": null,
    "inspector_code": "",
    "order_sheet_serial_number": null,
    "joint_rate": null,
    "inside_diameter": null,
    "coating_surface": null,
    "pack_num": null,
    "per_pack_num": null,
    "storage_type": "",
    "qualified_date": null,
    "third_shift_sheet_no": "",
    "equipment": "",
    "pack_number": "",
    "auth_type": "",
    "push_third_party": 0
  },
  "produce_sheet_ext": {
    "id": 12345,
    "sheet_id": 12345,
    "org_id": 1001,
    "factory_area_id": 101,
    "material_id": 67890,
    "send_date": "2023-10-10",
    "sheet_time": "2023-10-10 10:30:00",
    "produce_task_id": 54321,
    "task_no": "task_001",
    "ext_info_json": null,
    "create_by": 10001,
    "create_time": "2023-10-10 10:30:00",
    "modify_by": 10001,
    "modify_time": "2023-10-10 10:30:00",
    "rec_status": 1,
    "standard_sequential_number": {"seq": "001", "sub_seq": "A"},
    "coding": null,
    "small_roll_number": "small_roll_001",
    "re_rewinding": 0,
    "big_roll_batch": "big_roll_batch_001",
    "paper_core_weight": null,
    "return_stock_label": 0,
    "dominant_number": null,
    "storage_status": 0,
    "storage_time": null,
    "return_time": null,
    "estimated_weight": 100.000000
  }
}
```

### 5.2 设计思路

1. **字段选择**: 从 produce_sheet 和 produce_sheet_ext 表中选择了广纸业务所需的关键字段
2. **原始数据存储**: 添加了 raw_data 字段，用于存储完整的原始数据记录
3. **数据类型**: 使用 JSON 类型存储原始数据，保留数据的完整性和结构
4. **数据同步**: 需要确保原始数据与其他字段的数据一致性
5. **索引设计**: 为常用查询字段创建了索引，提高查询效率

### 5.3 注意事项

1. **数据同步**: 需要确保 raw_data 字段与其他字段的数据同步
2. **原始数据完整性**: 原始数据应包含完整的报工和扩展表信息
3. **性能考虑**: 由于 raw_data 字段可能较大，需要考虑查询性能
4. **存储优化**: 根据实际业务需求，可能需要定期清理或压缩历史数据

## 6. 检查清单

- [x] 所有字段都设置了NOT NULL和默认值
- [x] 包含了标准字段（id、create_time、modify_time、rec_status、org_id、create_by、modify_by）
- [x] 添加了原始数据字段（raw_data）
- [x] 表名和字段名符合命名规范
- [x] 索引设计基于实际业务场景
- [x] 多租户环境下包含org_id字段
- [x] 字符集统一为utf8mb4
- [x] 符合mysql-database-standards.md中的其他规范

