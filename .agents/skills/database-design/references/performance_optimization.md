# 性能优化指南

## 索引设计原则

### 索引的作用

1. **加速查询**: 通过索引快速定位数据
2. **加速排序**: 利用索引的有序性加速ORDER BY
3. **加速连接**: 加速JOIN操作
4. **唯一性约束**: 确保数据唯一性

### 索引类型

#### B-Tree索引（默认）

**适用场景**:
- 等值查询（=）
- 范围查询（>, <, BETWEEN）
- 排序（ORDER BY）
- 前缀匹配（LIKE 'prefix%'）

**不适用场景**:
- 后缀匹配（LIKE '%suffix'）
- 全模糊匹配（LIKE '%keyword%'）

#### 全文索引（FULLTEXT）

**适用场景**:
- 文本搜索
- 关键词检索

**MySQL8示例**:
```sql
CREATE FULLTEXT INDEX ft_content ON articles(title, content);
```

#### 哈希索引

**适用场景**:
- 等值查询
- 内存表（MEMORY引擎）

**限制**: 不支持范围查询和排序。

### 索引设计策略

#### 1. 主键索引

**自动创建**: 主键自动创建聚簇索引

**设计原则**:
- 使用自增ID或有序ID（如雪花ID）
- 避免使用随机UUID作为主键（影响插入性能）

#### 2. 唯一索引

**创建场景**:
- 业务唯一字段（如：用户名、邮箱、订单号）

**命名规范**: `uk_表名_字段名`

```sql
CREATE UNIQUE INDEX uk_users_email ON users(email);
```

#### 3. 普通索引

**创建场景**:
- 频繁查询的字段
- 外键关联字段（虽然不设置外键约束，但要创建索引）
- 排序字段
- 分组字段

**命名规范**: `idx_表名_字段名`

```sql
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at);
```

#### 4. 复合索引

**创建场景**:
- 多字段组合查询
- 覆盖索引优化

**设计原则**:
- **最左前缀原则**: 索引字段顺序很重要
- **选择性高的字段在前**: 区分度高的字段放在前面
- **查询频率高的字段在前**: 常用字段放在前面

**示例**:
```sql
-- 查询: WHERE user_id = ? AND status = ? ORDER BY created_at DESC
CREATE INDEX idx_orders_user_status_created ON orders(user_id, status, created_at);
```

**覆盖索引**: 索引包含查询所需的所有字段，避免回表

```sql
-- 查询: SELECT id, user_id, status FROM orders WHERE user_id = ?
-- 索引包含所有查询字段
CREATE INDEX idx_orders_user_status ON orders(user_id, status);
```

### 索引设计检查清单

- [ ] 主键是否有索引？（自动创建）
- [ ] 唯一字段是否有唯一索引？
- [ ] 外键关联字段是否有索引？
- [ ] 频繁查询的WHERE条件字段是否有索引？
- [ ] 频繁排序的ORDER BY字段是否有索引？
- [ ] 频繁分组的GROUP BY字段是否有索引？
- [ ] 复合查询是否有合适的复合索引？
- [ ] 是否创建了不必要的索引？（影响写入性能）

## 查询性能优化

### 字段类型优化

**原则**: 选择最小合适的类型

- **整数类型**: 选择能满足需求的最小类型
- **字符串类型**: 设置合理的最大长度
- **避免TEXT**: 如果可能，使用VARCHAR替代TEXT

### 避免全表扫描

**方法**:
- 为WHERE条件字段创建索引
- 避免在WHERE子句中使用函数
- 避免在WHERE子句中进行类型转换

**错误示例**:
```sql
-- 错误：函数导致索引失效
SELECT * FROM users WHERE DATE(created_at) = '2024-01-01';

-- 正确：使用范围查询
SELECT * FROM users WHERE created_at >= '2024-01-01 00:00:00' 
  AND created_at < '2024-01-02 00:00:00';
```

### 分页优化

**问题**: LIMIT OFFSET在大偏移量时性能差

**解决方案**:

1. **游标分页**（推荐）
```sql
-- 使用ID作为游标
SELECT * FROM orders WHERE id > ? ORDER BY id LIMIT 20;
```

2. **延迟关联**
```sql
-- 先获取ID，再获取数据
SELECT * FROM orders o
INNER JOIN (
    SELECT id FROM orders ORDER BY created_at DESC LIMIT 10000, 20
) t ON o.id = t.id;
```

### JOIN优化

**原则**:
- 确保JOIN字段有索引
- 小表驱动大表
- 避免多表JOIN（考虑反范式化）

## 写入性能优化

### 批量插入

**使用批量插入代替逐条插入**:
```sql
-- 推荐
INSERT INTO users (username, email) VALUES 
('user1', 'user1@example.com'),
('user2', 'user2@example.com'),
('user3', 'user3@example.com');

-- 避免
INSERT INTO users (username, email) VALUES ('user1', 'user1@example.com');
INSERT INTO users (username, email) VALUES ('user2', 'user2@example.com');
INSERT INTO users (username, email) VALUES ('user3', 'user3@example.com');
```

### 索引对写入的影响

**影响**:
- 每个索引都会增加写入开销
- 复合索引比单列索引开销更大

**原则**:
- 只创建必要的索引
- 定期审查索引使用情况，删除未使用的索引

### 事务优化

**原则**:
- 事务范围尽量小
- 避免长事务
- 合理使用事务隔离级别

## 表结构优化

### 垂直拆分

**场景**: 表字段很多，但经常只查询部分字段

**方法**: 将表拆分为主表和扩展表

```sql
-- 主表：存储常用字段
CREATE TABLE users (
    id BIGINT UNSIGNED PRIMARY KEY,
    username VARCHAR(50),
    email VARCHAR(100),
    -- 其他常用字段
);

-- 扩展表：存储不常用字段
CREATE TABLE user_ext (
    user_id BIGINT UNSIGNED PRIMARY KEY,
    bio TEXT,
    preferences JSON,
    -- 其他不常用字段
);
```

### 水平拆分

**场景**: 单表数据量过大

**方法**: 按时间、ID范围、业务维度分表

**设计考虑**:
- 分表策略（按时间、按ID范围、按业务）
- 路由规则
- 跨表查询处理

### 归档策略

**场景**: 历史数据访问频率低

**方法**: 将历史数据迁移到归档表

```sql
-- 主表：存储近期数据
CREATE TABLE orders (
    -- 字段定义
);

-- 归档表：存储历史数据
CREATE TABLE orders_archive (
    -- 字段定义（与主表相同）
);
```

## MySQL8特性优化

### 窗口函数

**用途**: 复杂分析查询

```sql
-- 计算每个用户的订单排名
SELECT 
    id,
    user_id,
    total_amount,
    ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY total_amount DESC) as rank
FROM orders;
```

### CTE (Common Table Expressions)

**用途**: 提高复杂查询可读性

```sql
WITH user_orders AS (
    SELECT user_id, COUNT(*) as order_count
    FROM orders
    GROUP BY user_id
)
SELECT u.username, uo.order_count
FROM users u
JOIN user_orders uo ON u.id = uo.user_id;
```

### JSON字段

**用途**: 存储半结构化数据

```sql
CREATE TABLE products (
    id BIGINT UNSIGNED PRIMARY KEY,
    name VARCHAR(100),
    attributes JSON COMMENT '商品属性',
    INDEX idx_attributes ((CAST(attributes->'$.color' AS CHAR(20))))
);
```

## 性能监控

### 慢查询日志

**启用慢查询日志**:
```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2; -- 超过2秒的查询记录
```

### EXPLAIN分析

**使用EXPLAIN分析查询计划**:
```sql
EXPLAIN SELECT * FROM orders WHERE user_id = 1;
```

**关注指标**:
- type: 访问类型（ALL最差，const最好）
- key: 使用的索引
- rows: 扫描行数
- Extra: 额外信息（Using filesort、Using temporary需要优化）

## 优化检查清单

- [ ] 是否创建了必要的索引？
- [ ] 是否避免了不必要的索引？
- [ ] 字段类型是否最优？
- [ ] 查询是否使用了索引？
- [ ] 分页查询是否优化？
- [ ] JOIN操作是否优化？
- [ ] 是否考虑了表拆分？
- [ ] 是否考虑了数据归档？
