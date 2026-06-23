---
name: database-design
description: 企业级数据库架构设计专家，将业务流程转化为高效、可扩展的数据库模式。精通数据库设计原则、范式理论、关系建模和性能优化，特别擅长MySQL8和PostgreSQL。当用户需要设计数据库表结构、分析业务实体关系、创建数据库模式文档、优化数据库性能或进行数据库架构规划时使用此技能。
---

# 数据库设计

## 概述

本技能提供企业级数据库架构设计能力，将复杂的业务流程转化为高效、可扩展的数据库模式。专注于MySQL8，严格遵循 `references/mysql-database-standards.md` 中的规范，确保设计既满足业务需求，又具备良好的性能和扩展性。

## 核心能力

1. **业务分析** - 深入分析业务流程，识别实体、属性和业务规则
2. **关系建模** - 确定实体间关系（一对一、一对多、多对多）
3. **表结构设计** - 设计符合范式理论的表结构，定义字段类型和约束
4. **性能优化** - 索引策略、字段类型优化、查询模式优化
5. **文档输出** - 生成完整的数据库模式设计文档，包括表结构、关系图和说明

## 设计工作流

### 1. 业务分析阶段

深入分析用户提供的业务流程：

- 识别所有业务实体（如用户、订单、产品等）
- 提取每个实体的关键属性
- 理解业务规则和约束条件
- 识别业务操作和数据流转

**参考文档**: 结合业务需求分析，参考 `references/mysql-database-standards.md` 中的建表规范

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

**参考文档**: 性能优化策略参考 `references/mysql-database-standards.md` 中的索引设计和查询优化章节

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

- **表名**: 不使用复数名词，小写字母+下划线，项目相关表名必须添加项目前缀（格式：项目前缀_表名）
  - 正例：`yt_user_info`（燕塘业务用户表），`yt_order_detail`（燕塘业务订单详情表）
  - 反例：`user_infos`（使用复数），`userInfo`（驼峰命名）
- **字段名**: 小写字母+下划线，见名知意，禁止与MySQL关键字重名
- **索引名**: 普通单字段索引 `idx_字段名`，联合索引 `idx_字段1_字段2`，多租户索引包含org_id
  - 正例：`idx_org_id`（单字段），`idx_org_status`（联合），`uk_org_email`（唯一）
- **唯一索引**: `uk_前缀 + 枚举所有列（全小写）`

### 字段设计规范

- **ID字段**: 统一使用 `id` 作为主键名，类型为 `BIGINT(20) UNSIGNED AUTO_INCREMENT`（MySQL8）
- **时间字段**: 使用 `create_time` 和 `modify_time`，类型为 `DATETIME`
  - `create_time`: `NOT NULL DEFAULT CURRENT_TIMESTAMP`（不自动更新）
  - `modify_time`: `NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`（自动更新）
- **软删除**: 使用 `rec_status` 字段，类型为 `TINYINT(4) NOT NULL DEFAULT 1`（1-有效，0-删除）
- **状态字段**: 使用TINYINT或SMALLINT，添加注释说明各状态值
- **金额字段**: 使用 `DECIMAL(10,2)` 或 `INT`（程序端乘以100存储分），避免使用浮点数

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
- **分页查询**: 考虑LIMIT/OFFSET的性能问题，设计支持主键分页（`WHERE id > #{lastId} LIMIT #{pageSize}`）
- **批量操作**: 表结构设计支持批量插入和更新
- **事务支持**: 确保表结构支持事务操作
- **多租户支持**: 所有业务表必须包含org_id字段，确保数据隔离

## 与MySQL数据库规范的一致性

本技能的数据库设计严格遵循 `references/mysql-database-standards.md` 中的规范，包括：

1. **建表规约**: 所有表必须包含标准字段（id、create_time、modify_time、rec_status、org_id、create_by、modify_by）
2. **字段规范**: 所有字段必须设置NOT NULL和默认值，禁止NULL值
3. **索引设计**: 建表时只创建主键索引，后续根据业务需求添加，多租户索引必须包含org_id作为第一列
4. **SQL规范**: 使用大写关键字，字段名用反引号包围，避免使用外键和存储过程
5. **性能优化**: 合理使用数据类型，避免函数运算，优化查询模式

## 设计检查清单

在完成数据库设计后，必须检查以下项目：

- [ ] 所有表是否包含标准字段（id、create_time、modify_time、rec_status、org_id、create_by、modify_by）
- [ ] 所有字段是否设置了NOT NULL和合理的默认值
- [ ] 表名和字段名是否符合命名规范
- [ ] 索引设计是否基于实际业务场景
- [ ] 多租户环境下是否包含org_id条件
- [ ] 字符集是否统一为utf8mb4
- [ ] 是否避免了使用enum、set、blob、text等不推荐类型
- [ ] 是否符合mysql-database-standards.md中的其他规范

## 常见设计模式

### 审计字段模式

每个表包含标准审计字段：

```sql
create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
create_by BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人ID',
modify_by BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '修改人ID'
```

### 软删除模式

使用 `rec_status` 字段实现软删除：

```sql
rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除'
```

查询时过滤：`WHERE rec_status = 1`

### 多租户模式

在表结构中添加机构ID（org_id）：

```sql
org_id BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '机构ID',
INDEX idx_org_id (org_id)
```

**注意**: 多租户环境下，所有业务查询必须包含org_id条件，索引设计必须包含org_id作为第一列。

### 版本控制模式

对于需要版本控制的表，添加版本字段：

```sql
version INT UNSIGNED NOT NULL DEFAULT 1 COMMENT '版本号',
```

## 参考资源

- **MySQL数据库规范**: `references/mysql-database-standards.md` - 包含建表规约、SQL规范、索引设计、性能优化等完整指南
- **表设计规范**: `references/table_design.md` - 详细的表结构设计指南，包括字段类型选择、约束设计等
- **输出格式**: `references/output_format.md` - 数据库设计文档的标准格式，包括SQL建表语句、ER图等

## 使用示例

**用户请求**: "设计一个电商系统的数据库，包含用户、商品、订单、购物车等功能"

**处理流程**:
1. 分析业务实体：用户、商品、订单、订单项、购物车、分类等
2. 确定关系：用户-订单（一对多）、订单-订单项（一对多）、商品-订单项（一对多）、用户-购物车（一对多）、商品-分类（多对多）
3. 设计表结构：users, products, orders, order_items, cart_items, categories, product_categories
4. 设计索引：为外键字段、查询字段创建索引
5. 生成文档：包含完整的SQL建表语句、ER图和设计说明
