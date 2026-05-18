# 表设计规范

## 命名规范

### 表名规范

- 【强制】表名必须使用小写字母或数字，禁止数字开头，禁止两个下划线中间只出现数字
- 【强制】表名不使用复数名词
- 【强制】项目相关表名必须添加项目前缀，格式：项目前缀_表名
  - 正例：`yt_user_info`（燕塘业务用户表），`yt_order_detail`（燕塘业务订单详情表）
  - 反例：`user_info`（缺少项目前缀），`ytuser_info`（前缀格式错误）
- 【强制】表名、字段名必须使用小写字母或数字，禁止数字开头，禁止两个下划线中间只出现数字
  - 正例：`getter_admin`，`task_config`，`level3_name`
  - 反例：`GetterAdmin`，`taskConfig`，`level_3_name`

### 字段名规范

- 【强制】字段名必须使用小写字母或数字，禁止数字开头
- 【强制】字段名不能与MySQL中的关键字重名
- 【强制】所有表名、字段名必须加注释，且命名需与实际含义一致
- 【推荐】表命名、字段命名不使用拼音，更不推荐使用拼音首字母

## 字段类型选择

### 整数类型

| MySQL8 | PostgreSQL | 范围 | 用途 |
|--------|-----------|------|------|
| TINYINT | SMALLINT | -128 to 127 | 状态值、枚举值（推荐用于status、type等选择性少的字段） |
| SMALLINT | SMALLINT | -32,768 to 32,767 | 小整数 |
| INT | INTEGER | -2^31 to 2^31-1 | 一般整数、IP地址（推荐用int存储IP，占4字节） |
| BIGINT | BIGINT | -2^63 to 2^63-1 | ID、大整数 |
| INT UNSIGNED | - | 0 to 2^32-1 | 非负整数（MySQL） |
| BIGINT UNSIGNED | - | 0 to 2^64-1 | 非负大整数（MySQL） |

**选择原则**: 
- 选择能满足需求的最小类型，节省存储空间
- 【建议】业务中选择性很少的状态status、类型type等字段推荐使用tinyint或smallint类型节省存储空间
- 【建议】业务中IP地址字段推荐使用int类型，不推荐用char(15)
  - int只占4字节，char(15)占用至少15字节
  - 转换函数：`SELECT INET_ATON('192.168.2.12'); SELECT INET_NTOA(3232236044);`

### 字符串类型

| MySQL8 | PostgreSQL | 用途 |
|--------|-----------|------|
| CHAR(n) | CHAR(n) | 固定长度字符串（如：状态码、代码） |
| VARCHAR(n) | VARCHAR(n) | 可变长度字符串（如：姓名、标题） |
| TEXT | TEXT | 长文本（如：内容、描述） |
| MEDIUMTEXT | TEXT | 中等长度文本 |
| LONGTEXT | TEXT | 超长文本 |

**选择原则**:
- 【推荐】文本数据尽量用varchar存储
  - varchar是变长存储，比char更省空间
  - 【建议】varchar长度设置为2的幂次方（如32、64、128、256、512、1024等）
  - MySQL server层规定一行所有文本最多存65535字节，因此在utf8字符集下最多存21844个字符
  - 一般建议用varchar类型，字符数不要超过2700
- 【推荐】非必要不使用text类型字段
  - 若必须使用，需在提交申请时说明理由
  - 建议优先使用带长度的varchar，并在落库前做超长截断处理
  - text、blob等类型比较浪费硬盘和内存空间，在加载表数据时会读取大字段到内存里从而浪费内存空间，影响系统性能

**注意**: VARCHAR在MySQL8中最大65535字节，实际可用长度取决于字符集。

### 日期时间类型

| MySQL8 | PostgreSQL | 用途 |
|--------|-----------|------|
| DATE | DATE | 日期（年月日） |
| TIME | TIME | 时间（时分秒） |
| DATETIME | TIMESTAMP | 日期时间（**强制使用**） |
| TIMESTAMP | TIMESTAMP | 时间戳（自动时区转换） |
| YEAR | - | 年份（MySQL） |

**选择原则**:
- 【强制】时间字段必须使用datetime类型，且必须有默认值
- 【强制】create_time默认值：CURRENT_TIMESTAMP，不自动更新
- 【强制】modify_time默认值：CURRENT_TIMESTAMP，自动更新（ON UPDATE CURRENT_TIMESTAMP）
- 【强制】其他时间字段默认值：'1970-01-01 08:00:00'，不自动更新
- DATE: 只需要日期（较少使用）

### 数值类型

| MySQL8 | PostgreSQL | 用途 |
|--------|-----------|------|
| DECIMAL(p,s) | DECIMAL(p,s) | 精确小数（金额、比例） |
| INT | INTEGER | 金额存储（推荐，程序端乘以100和除以100进行存取） |
| FLOAT | REAL | 单精度浮点数（**禁止使用**） |
| DOUBLE | DOUBLE PRECISION | 双精度浮点数（**禁止使用**） |

**选择原则**:
- 【强制】小数类型必须使用decimal，禁止使用float和double
- 【建议】存储金钱的字段，建议用int，程序端乘以100和除以100进行存取
  - int占用4字节，而double占用8字节，空间浪费
  - 示例：存储100.50元，使用int存储10050，程序端除以100显示
- DECIMAL: 需要精确计算的场景（如比例、百分比等）

**金额字段**: 
- 推荐使用 `INT` 类型，程序端乘以100和除以100进行存取
- 或使用 `DECIMAL(10,2)` 或 `DECIMAL(19,4)`，避免使用FLOAT/DOUBLE

### JSON类型

| MySQL8 | PostgreSQL | 用途 |
|--------|-----------|------|
| JSON | JSONB | 半结构化数据 |

**选择原则**: 用于存储结构不固定或需要灵活扩展的数据。

### 枚举类型

- 【建议】不推荐使用enum、set类型
  - 它们浪费空间，且枚举值写死了，变更不方便
  - 推荐使用tinyint或smallint替代

## 主键设计

### 主键类型选择

1. **自增ID** (AUTO_INCREMENT / SERIAL) - **推荐**
   - 优点: 简单、高效、有序
   - 缺点: 分表分库时可能冲突
   - 适用: 单表或单库场景

2. **UUID**
   - 优点: 全局唯一、适合分布式
   - 缺点: 存储空间大、无序、性能略差
   - 适用: 分布式系统、多租户系统

3. **雪花ID** (Snowflake)
   - 优点: 全局唯一、有序、高性能
   - 缺点: 需要额外服务生成
   - 适用: 大型分布式系统

4. **业务主键**
   - 优点: 有业务含义
   - 缺点: 可能变化、长度不定
   - 适用: 业务编号作为主键的场景

### 推荐方案

**标准方案**: 使用 `BIGINT(20) UNSIGNED AUTO_INCREMENT` (MySQL8)

```sql
id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY COMMENT '主键ID'
```

**注意**: 
- 数字类型字段的默认值必须使用数字格式，禁止使用字符串格式
  - 正确示例：`BIGINT(20) UNSIGNED NOT NULL DEFAULT 0`
  - 错误示例：`BIGINT(20) UNSIGNED NOT NULL DEFAULT '0'`

## 约束设计

### NOT NULL约束

**原则**: 【强制】所有字段（含时间戳字段）不能为null，且都需要有默认值（NOT NULL DEFAULT XXX）

- **所有字段**: 必须添加 `NOT NULL` 和 `DEFAULT` 值
- **禁止**: 不允许字段为 `NULL`（除非特殊业务需求）

### UNIQUE约束

**原则**: 确保字段值唯一

```sql
email VARCHAR(100) NOT NULL DEFAULT '' UNIQUE COMMENT '邮箱'
```

**注意**: 
- 唯一约束会自动创建唯一索引
- 多租户环境下，唯一性约束必须包含org_id，确保跨租户数据独立性
- 唯一索引命名：`uk_前缀 + 枚举所有列（全小写）`

### CHECK约束

**原则**: 限制字段取值范围（较少使用）

```sql
status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-启用，2-禁用',
CHECK (status IN (1, 2))
```

**注意**: MySQL8支持CHECK约束，但默认不强制执行（需要设置sql_mode）。推荐使用tinyint配合注释说明取值范围。

### 默认值

**原则**: 【强制】为所有字段设置合理的默认值

**数字类型默认值**:
- 【强制】数字类型字段的默认值必须使用数字格式，禁止使用字符串格式
  - 正确示例：`TINYINT(4) NOT NULL DEFAULT 1`、`BIGINT(20) UNSIGNED NOT NULL DEFAULT 0`
  - 错误示例：`TINYINT(4) NOT NULL DEFAULT '1'`、`BIGINT(20) UNSIGNED NOT NULL DEFAULT '0'`

**时间类型默认值**:
```sql
create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
other_time DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '其他时间'
```

**字符串类型默认值**:
```sql
name VARCHAR(100) NOT NULL DEFAULT '' COMMENT '名称',
status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态'
```

## 字段注释

**原则**: 【强制】为每个字段添加清晰的注释

```sql
user_name VARCHAR(50) NOT NULL DEFAULT '' COMMENT '用户名，3-20个字符，支持字母、数字、下划线',
email VARCHAR(100) NOT NULL DEFAULT '' COMMENT '邮箱地址，用于登录和找回密码',
status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-正常，2-禁用，3-删除'
```

**注释内容**:
- 字段的业务含义
- 取值范围或格式要求
- 特殊说明（如：加密存储、关联关系等）
- 【强制】所有表名、字段名必须加注释，且命名需与实际含义一致

## 标准字段规范

### 【强制】所有表必须包含以下字段

- **id**: 自增主键，`BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT`
- **create_time**: 创建时间，`DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP`
- **modify_time**: 修改时间，`DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP`
- **rec_status**: 逻辑删除标记，`TINYINT(4) NOT NULL DEFAULT 1`（1-有效，0-删除）
- **org_id**: 机构id（后端业务表必需），`BIGINT(20) UNSIGNED NOT NULL DEFAULT 0`
- **create_by**: 创建人（后端业务表必需），`BIGINT(20) UNSIGNED NOT NULL DEFAULT 0`
- **modify_by**: 修改人（后端业务表必需），`BIGINT(20) UNSIGNED NOT NULL DEFAULT 0`

## 表设计示例

### 标准用户表（多租户）

```sql
CREATE TABLE `yt_user_info` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `username` VARCHAR(50) NOT NULL DEFAULT '' COMMENT '用户名',
  `email` VARCHAR(100) NOT NULL DEFAULT '' COMMENT '邮箱',
  `password_hash` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '密码哈希值',
  `phone` VARCHAR(20) NOT NULL DEFAULT '' COMMENT '手机号',
  `avatar_url` VARCHAR(500) NOT NULL DEFAULT '' COMMENT '头像URL',
  `status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-正常，2-禁用',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='燕塘业务用户信息表';

-- 后续根据业务查询需求添加索引，例如：
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_id` (`org_id`);
-- ALTER TABLE `yt_user_info` ADD KEY `idx_org_status` (`org_id`, `status`);
-- ALTER TABLE `yt_user_info` ADD UNIQUE KEY `uk_org_email` (`org_id`, `email`);
```

### 订单表（多租户）

```sql
CREATE TABLE `yt_order_info` (
  `id` BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单ID',
  `user_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '用户ID',
  `order_no` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '订单号',
  `total_amount` INT(11) NOT NULL DEFAULT 0 COMMENT '订单总金额（分）',
  `status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '订单状态：1-待支付，2-已支付，3-已发货，4-已完成，5-已取消',
  `payment_method` VARCHAR(20) NOT NULL DEFAULT '' COMMENT '支付方式',
  `payment_time` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '支付时间',
  `shipping_address` VARCHAR(500) NOT NULL DEFAULT '' COMMENT '收货地址',
  `create_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `modify_time` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
  `rec_status` TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
  `org_id` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '机构ID',
  `create_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '创建人ID',
  `modify_by` BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '修改人ID',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='燕塘业务订单信息表';

-- 后续根据业务查询需求添加索引，例如：
-- ALTER TABLE `yt_order_info` ADD KEY `idx_org_user_id` (`org_id`, `user_id`);
-- ALTER TABLE `yt_order_info` ADD KEY `idx_org_status` (`org_id`, `status`);
-- ALTER TABLE `yt_order_info` ADD UNIQUE KEY `uk_order_no` (`order_no`);
```

### 索引设计说明

- 【强制】建表时只创建主键索引，不创建其他索引，避免提前设计导致的索引冗余
- 【强制】多租户环境下，所有业务查询索引必须包含org_id字段作为第一列
- 【强制】索引设计基于实际业务查询场景，通过慢查询日志和EXPLAIN分析确定
- 索引命名规范：
  - 普通单字段索引：`idx_前缀 + 字段名（全小写）`
  - 普通联合索引：`idx_前缀 + 枚举所有列（全小写）`
  - 唯一索引：`uk_前缀 + 枚举所有列（全小写）`
  - 多租户索引：`idx_org_字段名` 或 `idx_字段名_org_id`

## 字符集规范

- 【强制】数据库本身库、表、列所有字符集必须保持一致，为utf8或utf8mb4
- 【强制】前端程序字符集或者环境变量中的字符集，与数据库、表的字符集必须一致，统一为utf8
- 【强制】建表语句必须指定字符集和排序规则：`DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`

## 设计检查清单

### 命名规范
- [ ] 表名是否使用小写字母或数字，禁止数字开头？
- [ ] 表名是否不使用复数名词？
- [ ] 项目相关表名是否添加了项目前缀（格式：项目前缀_表名）？
- [ ] 字段名是否使用小写字母或数字，禁止数字开头？
- [ ] 字段名是否与MySQL关键字冲突？

### 字段规范
- [ ] 所有字段是否都设置了NOT NULL和DEFAULT值？
- [ ] 是否包含了标准字段：id, create_time, modify_time, rec_status, org_id, create_by, modify_by？
- [ ] 时间字段是否使用DATETIME类型？
- [ ] create_time默认值是否为CURRENT_TIMESTAMP（不自动更新）？
- [ ] modify_time默认值是否为CURRENT_TIMESTAMP（自动更新）？
- [ ] 其他时间字段默认值是否为'1970-01-01 08:00:00'？

### 数据类型
- [ ] 字段类型选择是否合适（选择最小合适的类型）？
- [ ] 字段长度是否合理（varchar长度是否为2的幂次方）？
- [ ] 小数类型是否使用decimal，禁止使用float和double？
- [ ] 金额字段是否考虑使用int类型（程序端乘以100和除以100）？
- [ ] 状态字段是否使用tinyint或smallint？
- [ ] IP地址字段是否使用int类型？
- [ ] 是否避免使用enum、set、blob、text类型（除非必要）？
- [ ] 数字类型字段的默认值是否使用数字格式（禁止字符串格式）？

### 约束和注释
- [ ] 是否添加了必要的约束？
- [ ] 字段注释是否清晰完整？
- [ ] 所有表名、字段名是否都加了注释？

### 主键和索引
- [ ] 主键设计是否合理（BIGINT(20) UNSIGNED AUTO_INCREMENT）？
- [ ] 建表时是否只创建主键索引，不创建其他索引？
- [ ] 多租户环境下，索引是否包含org_id字段作为第一列？

### 字符集
- [ ] 是否指定了字符集和排序规则（utf8mb4）？
