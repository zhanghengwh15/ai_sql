---
alwaysApply: false
---
# MySQL数据库规范

## 1. SQL上线流程规范

## 2. 建表规约

### 2.1 命名规范
- 【强制】所有表名、字段名必须加注释，且命名需与实际含义一致
- 【推荐】表命名、字段命名不使用拼音，更不推荐使用拼音首字母
- 【强制】表名不使用复数名词
- 【强制】项目相关表名必须添加项目前缀，格式：项目前缀_表名
  - 正例：yt_user_info（燕塘业务用户表），yt_order_detail（燕塘业务订单详情表）
  - 反例：user_info（缺少项目前缀），ytuser_info（前缀格式错误）
- 【强制】表名、字段名必须使用小写字母或数字，禁止数字开头，禁止两个下划线中间只出现数字
  - 正例：getter_admin，task_config，level3_name
  - 反例：GetterAdmin，taskConfig，level_3_name

### 2.2 字段规范
- 【强制】所有字段（含时间戳字段）不能为null，且都需要有默认值（NOT NULL DEFAULT XXX）
- 【强制】字段名不能与MySQL中的关键字重名
- 【强制】所有表必须包含以下字段：
  - id：自增主键，bigint(20) 无符号类型
  - create_time：创建时间
  - modify_time：修改时间
  - rec_status：逻辑删除标记
  - org_id：机构id（后端业务表必需）
  - create_by：创建人（后端业务表必需）
  - modify_by：修改人（后端业务表必需）

### 2.3 时间字段规范
- 【强制】时间字段必须使用datetime类型，且必须有默认值
- 【强制】create_time默认值：CURRENT_TIMESTAMP，不自动更新
- 【强制】modify_time默认值：CURRENT_TIMESTAMP，自动更新
- 【强制】其他时间字段默认值：'1970-01-01 08:00:00'，不自动更新

### 2.4 数据类型规范
- 【强制】小数类型必须使用decimal，禁止使用float和double
- 【强制】数字类型字段的默认值必须使用数字格式，禁止使用字符串格式
  - 正确示例：`tinyint(4) NOT NULL DEFAULT 1`、`bigint(20) unsigned NOT NULL DEFAULT 0`
  - 错误示例：`tinyint(4) NOT NULL DEFAULT '1'`、`bigint(20) unsigned NOT NULL DEFAULT '0'`
- 【推荐】非必要不使用text类型字段
  - 若必须使用，需在提交申请时说明理由
  - 建议优先使用带长度的varchar，并在落库前做超长截断处理
- 【建议】业务中选择性很少的状态status、类型type等字段推荐使用tinyint或smallint类型节省存储空间
- 【建议】业务中IP地址字段推荐使用int类型，不推荐用char(15)
  - int只占4字节，char(15)占用至少15字节
  - 一旦表数据行数到了1亿，那么要多用1.1G存储空间
  - 转换函数：
    - SQL：`select inet_aton('192.168.2.12'); select inet_ntoa(3232236044);`
    - PHP：`ip2long('192.168.2.12'); long2ip(3530427185);`
- 【建议】不推荐使用enum、set类型
  - 它们浪费空间，且枚举值写死了，变更不方便
  - 推荐使用tinyint或smallint替代
- 【建议】不推荐使用blob、text等类型
  - 它们都比较浪费硬盘和内存空间
  - 在加载表数据时，会读取大字段到内存里从而浪费内存空间，影响系统性能
  - 建议和PM、RD沟通，是否真的需要这么大字段
  - Innodb中当一行记录超过8098字节时，会将该记录中选取最长的一个字段将其768字节放在原始page里，该字段余下内容放在overflow-page里
  - 不幸的是在compact行格式下，原始page和overflow-page都会加载
- 【建议】存储金钱的字段，建议用int，程序端乘以100和除以100进行存取
  - int占用4字节，而double占用8字节，空间浪费
- 【建议】文本数据尽量用varchar存储
  - varchar是变长存储，比char更省空间，建议varchar长度设置为2的幂次方（如32、64、128、256、512、1024等）
  - MySQL server层规定一行所有文本最多存65535字节，因此在utf8字符集下最多存21844个字符，超过会自动转换为mediumtext字段
  - text在utf8字符集下最多存21844个字符，mediumtext最多存2^24/3个字符，longtext最多存2^32个字符
  - 一般建议用varchar类型，字符数不要超过2700

### 2.5 索引规范

#### 2.5.1 索引命名规范
- 【强制】普通单字段索引命名：idx_前缀 + 字段名（全小写）
- 【强制】普通联合索引命名：idx_前缀 + 枚举所有列（全小写）
- 【强制】唯一索引命名：uk_前缀 + 枚举所有列（全小写）
- 【强制】多租户索引必须包含org_id字段，命名格式：idx_org_字段名 或 idx_字段名_org_id
- 【强制】建表时只创建主键索引，不创建其他索引，后续根据业务查询需求统一添加

#### 2.5.2 索引设计原则
- 【强制】建表时只创建主键索引，不创建其他索引，避免提前设计导致的索引冗余
- 【强制】多租户环境下，所有业务查询索引必须包含org_id字段作为第一列
- 【强制】索引设计基于实际业务查询场景，通过慢查询日志和EXPLAIN分析确定
- 【强制】减少一个列在多个索引中出现，一般不超过3个索引，减少出现低效执行计划可能性
- 【强制】理解复合索引中列次序，及等值、in-list多值、区间匹配的区别
- 【强制】索引是trade-off，综合平衡考虑成本收益，需要控制索引数量
- 【强制】避免在列上函数运算，会导致全表扫描
- 【强制】关联列、强过滤条件列上考虑建索引
- 【强制】合理利用索引消除排序
- 【强制】合理建立复合索引，避免建超过3列的索引，每一个索引列要有过滤数据作用

#### 2.5.3 复合索引设计规则
- 【强制】复合索引遵循最左前缀原则
- 【强制】多租户环境下，org_id必须作为复合索引的第一列
- 【强制】等值查询列放在最前面，范围查询列放在后面
- 【强制】区分度高的列放在前面，区分度低的列放在后面
- 【强制】经常用于排序的列放在复合索引的后面
- 【强制】避免在复合索引中包含过多列，一般不超过3列

#### 2.5.4 索引使用注意事项
- 【强制】避免在WHERE条件中使用函数，会导致索引失效
- 【强制】避免使用!=、<>、NOT IN等操作符，会导致索引失效
- 【强制】避免使用LIKE '%xxx'模式，会导致索引失效
- 【强制】避免在索引列上进行运算，如WHERE id + 1 = 10
- 【强制】避免使用OR连接条件，除非OR的每个条件都有独立索引

### 2.6 字符集规范
- 【强制】数据库本身库、表、列所有字符集必须保持一致，为utf8或utf8mb4
- 【强制】前端程序字符集或者环境变量中的字符集，与数据库、表的字符集必须一致，统一为utf8

## 3. SQL语句规范

### 3.1 查询规范
- 【强制】不要使用count(列名)或count(常量)替代count(*)
- 【强制】使用ISNULL()判断NULL值
- 【强制】分页查询时，若count为0应直接返回
- 【推荐】避免使用in操作，若必须使用，控制元素数量在1000个以内

### 3.2 更新规范
- 【强制】数据订正时，删除和修改记录前必须先select确认
- 【强制】更新数据表记录时，必须同时更新modify_time字段
- 【推荐】不要写大而全的数据更新接口，只更新需要修改的字段

### 3.3 其他规范
- 【强制】禁止使用外键与级联
- 【强制】禁止使用存储过程
- 【推荐】表查询时不要使用*作为查询字段列表
- 【参考】@Transactional事务不要滥用，需考虑回滚方案

## 4. 建表示例

### 4.1 标准表结构
```sql
-- 燕塘业务示例表结构
CREATE TABLE `yt_user_info` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `name` varchar(100) NOT NULL DEFAULT '' COMMENT '用户名称',
  `status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '状态：1-启用，0-禁用',
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '账户余额',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='燕塘业务用户信息表';

-- 后续根据业务查询需求添加索引，例如：
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_id` (`org_id`);
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_status` (`org_id`, `status`);
-- ALTER TABLE `yt_user_info` ADD UNIQUE KEY `uk_org_name` (`org_id`, `name`);
```

### 4.2 索引命名示例
```sql
-- 单字段索引
KEY `idx_user_id` (`user_id`)

-- 联合索引
KEY `idx_status_create_time` (`status`, `create_time`)

-- 唯一索引
UNIQUE KEY `uk_code_org_id` (`code`, `org_id`)
```

### 4.3 索引设计最佳实践

#### 4.3.1 复合索引设计示例
```sql
-- 燕塘业务用户表索引设计示例（建表时只创建主键索引）
CREATE TABLE `yt_user_info` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `org_id` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '机构ID',
  `user_code` varchar(50) NOT NULL DEFAULT '' COMMENT '用户编码',
  `status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '状态：1-正常，2-禁用',
  `user_type` tinyint(4) NOT NULL DEFAULT 1 COMMENT '用户类型：1-普通，2-VIP',
  `create_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_login_time` datetime NOT NULL DEFAULT '1970-01-01 08:00:00',
  `rec_status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `create_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` bigint(20) unsigned NOT NULL DEFAULT 0 COMMENT '修改人ID',
  `modify_time` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='燕塘业务用户信息表';

-- 后续根据业务查询需求添加索引（通过ALTER TABLE添加）
-- 1. 按机构查询用户列表
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_id` (`org_id`);

-- 2. 按机构+状态查询用户
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_status` (`org_id`, `status`);

-- 3. 按机构+用户类型查询
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_type` (`org_id`, `user_type`);

-- 4. 防止同一机构下用户编码重复
-- ALTER TABLE `yt_user_info` ADD UNIQUE KEY `uk_org_user_code` (`org_id`, `user_code`);

-- 5. 按机构+创建时间排序查询
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_create_time` (`org_id`, `create_time`);

-- 6. 按机构+状态+创建时间查询
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_status_create_time` (`org_id`, `status`, `create_time`);
```

#### 4.3.2 索引使用场景分析
```sql
-- 场景1：多租户等值查询 + 范围查询
-- 索引：idx_org_status_create_time (org_id, status, create_time)
SELECT * FROM yt_user_info 
WHERE org_id = 100 AND status = 1 AND create_time > '2024-01-01';
-- 分析：org_id作为第一列确保多租户隔离，status使用等值查询，create_time使用范围查询

-- 场景2：多租户排序查询
-- 索引：idx_org_create_time (org_id, create_time)
SELECT * FROM yt_user_info 
WHERE org_id = 100 
ORDER BY create_time DESC;
-- 分析：org_id确保多租户隔离，利用索引消除排序，提高查询性能

-- 场景3：多租户唯一性约束
-- 索引：uk_org_user_code (org_id, user_code)
INSERT INTO yt_user_info (org_id, user_code, name) VALUES (100, 'USER001', '张三');
-- 分析：确保同一机构下用户编码唯一，不同机构可以有相同编码

-- 场景4：避免索引失效
-- 错误示例：函数运算导致索引失效
SELECT * FROM yt_user_info WHERE org_id = 100 AND DATE(create_time) = '2024-01-01';
-- 正确示例：使用范围查询
SELECT * FROM yt_user_info WHERE org_id = 100 AND create_time >= '2024-01-01 00:00:00' AND create_time < '2024-01-02 00:00:00';
```

#### 4.3.3 索引优化建议
```sql
-- 1. 多租户索引设计原则
-- 不推荐：缺少org_id的索引
KEY `idx_status` (`status`),
KEY `idx_create_time` (`create_time`)

-- 推荐：所有业务索引都包含org_id
KEY `idx_org_status` (`org_id`, `status`),
KEY `idx_org_create_time` (`org_id`, `create_time`)

-- 2. 避免过多索引
-- 不推荐：一个字段出现在多个索引中
KEY `idx_org_status` (`org_id`, `status`),
KEY `idx_org_status_type` (`org_id`, `status`, `user_type`),
KEY `idx_org_status_create_time` (`org_id`, `status`, `create_time`)

-- 推荐：合并相关索引，减少索引数量
KEY `idx_org_status_type_create_time` (`org_id`, `status`, `user_type`, `create_time`)

-- 3. 合理使用覆盖索引
-- 索引：idx_org_status_type (org_id, status, user_type)
SELECT org_id, status, user_type FROM yt_user_info WHERE org_id = 100;
-- 分析：查询字段都在索引中，无需回表查询

-- 4. 避免索引列运算
-- 错误示例
SELECT * FROM yt_user_info WHERE org_id + 1 = 101;
-- 正确示例
SELECT * FROM yt_user_info WHERE org_id = 100;
```

## 5. 查询优化建议

### 5.1 分页查询优化
```sql
-- 推荐：使用主键分页
SELECT * FROM table_name 
WHERE id > #{last_id} 
ORDER BY id ASC 
LIMIT #{page_size};

-- 避免：使用OFFSET分页（大数据量时性能差）
SELECT * FROM table_name 
ORDER BY id ASC 
LIMIT #{page_size} OFFSET #{offset};
```

### 5.2 批量操作优化
```sql
-- 推荐：批量插入
INSERT INTO table_name (field1, field2) VALUES 
(value1, value2),
(value3, value4);

-- 推荐：批量更新
UPDATE table_name 
SET field1 = CASE id 
    WHEN 1 THEN 'value1' 
    WHEN 2 THEN 'value2' 
END 
WHERE id IN (1, 2);
```

## 6. 存储优化建议

### 6.1 数据类型选择优化
- **状态字段优化**：业务中选择性很少的状态status、类型type等字段推荐使用tinyint或smallint类型节省存储空间
- **IP地址存储优化**：业务中IP地址字段推荐使用int类型，不推荐用char(15)
  - int只占4字节，char(15)占用至少15字节
  - 一旦表数据行数到了1亿，那么要多用1.1G存储空间
  - 转换函数：
    - SQL：`select inet_aton('192.168.2.12'); select inet_ntoa(3232236044);`
    - PHP：`ip2long('192.168.2.12'); long2ip(3530427185);`
- **枚举类型优化**：不推荐使用enum、set类型，推荐使用tinyint或smallint替代
- **大字段优化**：不推荐使用blob、text等类型，建议和PM、RD沟通是否真的需要这么大字段
- **金额字段优化**：存储金钱的字段，建议用int，程序端乘以100和除以100进行存取
- **文本字段优化**：文本数据尽量用varchar存储，一般建议字符数不要超过2700

### 6.2 存储空间优化示例
```sql
-- 优化前：使用char(15)存储IP地址
CREATE TABLE `user_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `ip_address` char(15) NOT NULL DEFAULT '' COMMENT 'IP地址',
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00 COMMENT '金额',
  `status` varchar(20) NOT NULL DEFAULT '' COMMENT '状态',
  PRIMARY KEY (`id`)
);

-- 优化后：使用int存储IP地址，tinyint存储状态
CREATE TABLE `user_log` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `ip_address` int(11) NOT NULL DEFAULT 0 COMMENT 'IP地址',
  `amount` int(11) NOT NULL DEFAULT 0 COMMENT '金额（分）',
  `status` tinyint(4) NOT NULL DEFAULT 1 COMMENT '状态：1-正常，2-异常',
  PRIMARY KEY (`id`)
);
```

## 7. 索引性能监控与维护

### 7.1 索引性能分析
```sql
-- 查看索引使用情况
SHOW INDEX FROM table_name;

-- 分析查询执行计划
EXPLAIN SELECT * FROM table_name WHERE condition;

-- 查看索引统计信息
SELECT 
    TABLE_NAME,
    INDEX_NAME,
    CARDINALITY,
    SUB_PART,
    PACKED,
    NULLABLE,
    INDEX_TYPE
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = 'your_database' 
AND TABLE_NAME = 'your_table';
```

### 7.2 索引维护建议
- 【推荐】定期分析慢查询日志，识别索引优化机会
- 【推荐】使用EXPLAIN分析查询执行计划，确保索引被正确使用
- 【推荐】定期更新表统计信息：`ANALYZE TABLE table_name;`
- 【推荐】监控索引碎片率，必要时重建索引：`OPTIMIZE TABLE table_name;`
- 【推荐】删除不再使用的索引，减少维护成本

### 7.3 索引性能优化检查清单
- [ ] 建表时是否只创建主键索引，不创建其他索引
- [ ] 多租户环境下，所有业务索引是否都包含org_id字段作为第一列
- [ ] 索引设计是否基于实际业务查询场景，通过慢查询日志和EXPLAIN分析确定
- [ ] 每个索引是否都有明确的业务场景支撑
- [ ] 复合索引的列顺序是否符合查询模式
- [ ] 是否避免了索引列上的函数运算
- [ ] 是否合理使用了覆盖索引
- [ ] 是否控制了索引数量，避免过多索引影响写入性能
- [ ] 是否定期监控索引使用情况和性能表现
- [ ] 后期添加的索引是否基于实际业务需求

## 8. 注意事项

### 8.1 性能考虑
- 避免在WHERE条件中使用函数，会导致索引失效
- 合理使用索引，避免过多索引影响写入性能
- 定期分析慢查询日志，优化性能瓶颈
- 监控索引碎片率，及时维护索引
- 多租户环境下，确保所有查询都包含org_id条件，避免跨租户数据泄露

### 8.2 多租户安全考虑
- 【强制】所有业务查询必须包含org_id条件，确保数据隔离
- 【强制】索引设计必须考虑多租户隔离，org_id作为第一列
- 【强制】唯一性约束必须包含org_id，确保跨租户数据独立性
- 【强制】定期检查是否有遗漏org_id条件的查询语句

### 8.3 数据安全
- 生产环境禁止直接执行DDL语句
- 重要数据操作前必须备份
- 使用事务确保数据一致性
- 确保字符集一致性，避免乱码问题

### 8.4 代码规范
- SQL语句使用大写关键字，提高可读性
- 字段名使用反引号包围，避免关键字冲突
- 注释要详细说明字段用途和取值范围
- 建表语句必须指定字符集和排序规则
- 应用程序连接数据库时必须指定正确的字符集
- 避免使用MySQL关键字作为字段名，如必须使用则用反引号包围
- 多租户环境下，所有SQL查询必须包含org_id条件
