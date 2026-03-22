---
name: database-design
description: 企业级数据库架构设计专家，将业务流程转化为高效、可扩展的数据库模式。精通数据库设计原则、范式理论、关系建模和性能优化，特别擅长MySQL8和PostgreSQL。当用户需要设计数据库表结构、分析业务实体关系、创建数据库模式文档、优化数据库性能或进行数据库架构规划时使用此技能。
---

# 数据库设计

## 概述

本技能提供企业级数据库架构设计能力，将复杂的业务流程转化为高效、可扩展的数据库模式。专注于MySQL8和PostgreSQL，确保设计既满足业务需求，又具备良好的性能和扩展性。

## 核心能力

1. **业务分析** - 深入分析业务流程，识别业务实体及其属性
2. **关系建模** - 确定实体间关系（一对一、一对多、多对多）
3. **表结构设计** - 设计符合范式理论的表结构，定义字段类型和约束
4. **性能优化** - 考虑索引设计、查询性能和后端扩展性
5. **文档输出** - 生成完整的数据库模式设计文档，包括表结构、关系图和说明

## 设计工作流

### 1. 业务分析阶段

深入分析用户提供的业务流程：

- 识别所有业务实体（如用户、订单、产品等）
- 提取每个实体的关键属性
- 理解业务规则和约束条件
- 识别业务操作和数据流转

**参考文档**: 详见 `references/business_analysis.md`

### 2. 关系建模阶段

确定实体之间的关系：

- **一对一关系**: 使用外键关联，或合并到同一表
- **一对多关系**: 在多的一方添加外键
- **多对多关系**: 创建中间关联表
- **继承关系**: 根据查询模式选择单表继承、类表继承或具体表继承

**注意**: 不设置数据库外键约束，但要在设计中清晰标注关联关系，便于Java后端通过代码维护数据完整性。

### 3. 表结构设计阶段

为每个表设计字段：

- **字段类型选择**: 根据数据特性和MySQL8/PostgreSQL特性选择合适类型
- **主键设计**: 优先使用自增ID或UUID，考虑分表分库场景
- **约束设计**: NOT NULL、UNIQUE、CHECK等约束
- **默认值**: 设置合理的默认值
- **注释**: 为每个字段添加清晰的注释说明

**参考文档**: 详见 `references/table_design.md`

### 4. 性能优化考虑

在设计阶段就考虑性能：

- **索引策略**: 
  - 主键自动创建聚簇索引
  - 为频繁查询的字段创建索引
  - 为外键关联字段创建索引
  - 考虑复合索引和覆盖索引
  - 避免过度索引影响写入性能
- **字段类型优化**: 选择最小合适的类型，减少存储和内存占用
- **分表分库考虑**: 为未来扩展预留设计空间
- **查询模式**: 根据常见查询模式优化表结构

**参考文档**: 详见 `references/performance_optimization.md`

### 5. 文档输出

生成完整的数据库设计文档，包含：

- **表结构描述**: 每个表的详细说明
- **字段定义**: 字段名、类型、约束、默认值、注释
- **关系说明**: 表之间的关联关系（不设置外键，但明确标注）
- **数据库关系图**: 使用Mermaid格式绘制ER图
- **设计思路**: 说明设计决策和考虑因素
- **索引设计**: 列出建议的索引及其用途

**输出格式**: 详见 `references/output_format.md`

## 设计原则

### 范式理论

- **第一范式 (1NF)**: 确保每个字段都是原子值，不可再分
- **第二范式 (2NF)**: 消除部分函数依赖，确保非主键字段完全依赖于主键
- **第三范式 (3NF)**: 消除传递依赖，确保非主键字段之间无依赖关系
- **BCNF**: 在3NF基础上进一步消除主属性对非主属性的依赖

**注意**: 根据实际业务需求，可以适当反范式化以提高查询性能。

### 命名规范

- **表名**: 使用复数形式，小写字母+下划线（如：`user_profiles`, `order_items`）
- **字段名**: 小写字母+下划线，见名知意（如：`created_at`, `user_id`）
- **索引名**: `idx_表名_字段名`（如：`idx_users_email`）
- **唯一索引**: `uk_表名_字段名`（如：`uk_users_username`）

### 字段设计规范

- **ID字段**: 统一使用 `id` 作为主键名，类型为 `BIGINT UNSIGNED`（MySQL8）或 `BIGSERIAL`（PostgreSQL）
- **时间字段**: 使用 `created_at` 和 `updated_at`，类型为 `TIMESTAMP` 或 `DATETIME`
- **软删除**: 使用 `deleted_at` 字段，类型为 `TIMESTAMP NULL`
- **状态字段**: 使用枚举类型或TINYINT，添加注释说明各状态值
- **金额字段**: 使用 `DECIMAL(10,2)` 或 `DECIMAL(19,4)`，避免使用浮点数

## MySQL8 特性应用

充分利用MySQL8的新特性：

- **窗口函数**: 在复杂查询场景中考虑使用
- **CTE (Common Table Expressions)**: 提高复杂查询的可读性
- **JSON字段**: 对于半结构化数据，考虑使用JSON类型
- **全文索引**: 对于文本搜索需求，使用FULLTEXT索引
- **生成列**: 使用虚拟列或存储列简化查询

## Java后端兼容性

考虑Java后端的特性和最佳实践：

- **避免外键约束**: 通过应用层维护数据完整性，提高性能
- **字段类型映射**: 确保数据库类型能正确映射到Java类型
- **分页查询**: 考虑LIMIT/OFFSET的性能问题，设计支持游标分页
- **批量操作**: 表结构设计支持批量插入和更新
- **事务支持**: 确保表结构支持事务操作

## 常见设计模式

### 审计字段模式

每个表包含标准审计字段：

```sql
created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
created_by BIGINT UNSIGNED COMMENT '创建人ID',
updated_by BIGINT UNSIGNED COMMENT '更新人ID'
```

### 软删除模式

使用 `deleted_at` 字段实现软删除：

```sql
deleted_at TIMESTAMP NULL COMMENT '删除时间，NULL表示未删除'
```

查询时过滤：`WHERE deleted_at IS NULL`

### 多租户模式

在表结构中添加租户ID：

```sql
tenant_id BIGINT UNSIGNED NOT NULL COMMENT '租户ID',
INDEX idx_tenant_id (tenant_id)
```

### 版本控制模式

对于需要版本控制的表，添加版本字段：

```sql
version INT UNSIGNED NOT NULL DEFAULT 1 COMMENT '版本号',
```

## 参考资源

- **业务分析指南**: `references/business_analysis.md` - 如何从业务流程中提取实体和关系
- **表设计规范**: `references/table_design.md` - 详细的表结构设计指南
- **性能优化**: `references/performance_optimization.md` - 索引设计和性能优化策略
- **输出格式**: `references/output_format.md` - 数据库设计文档的标准格式

## 使用示例

**用户请求**: "设计一个电商系统的数据库，包含用户、商品、订单、购物车等功能"

**处理流程**:
1. 分析业务实体：用户、商品、订单、订单项、购物车、分类等
2. 确定关系：用户-订单（一对多）、订单-订单项（一对多）、商品-订单项（一对多）、用户-购物车（一对多）、商品-分类（多对多）
3. 设计表结构：users, products, orders, order_items, cart_items, categories, product_categories
4. 设计索引：为外键字段、查询字段创建索引
5. 生成文档：包含完整的SQL建表语句、ER图和设计说明
