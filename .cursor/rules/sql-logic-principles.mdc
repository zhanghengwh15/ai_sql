# SQL逻辑原则

## 核心原则

### 整洁是第一要素
- 整洁的代码不一定是好代码，但好代码一定是整洁的
- 设计的越简单才越有生命力
- 复杂的事情，往往有简单解
- 你的sql、你的注释，尽可能的让小白都能读得懂

## SQL编写规范

### 1. 可读性优先
- 【强制】SQL语句使用大写关键字，提高可读性
- 【强制】字段名使用反引号包围，避免关键字冲突
- 【强制】每个SQL语句都要有清晰的注释说明用途
- 【推荐】复杂查询拆分为多个简单查询，避免过度嵌套

### 2. 命名规范
- 【强制】表名、字段名使用小写字母和下划线
- 【强制】别名使用有意义的名称，避免a、b、c等无意义别名
- 【推荐】临时表别名使用表名缩写，如user_info → ui

### 3. 格式规范
```sql
-- 推荐：清晰的格式和缩进
SELECT 
    u.id,
    u.user_name,
    u.email,
    o.order_no,
    o.amount
FROM user_info u
INNER JOIN order_info o ON u.id = o.user_id
WHERE u.status = 1
    AND o.create_time >= '2024-01-01'
ORDER BY o.create_time DESC;

-- 不推荐：混乱的格式
SELECT u.id,u.user_name,u.email,o.order_no,o.amount FROM user_info u INNER JOIN order_info o ON u.id=o.user_id WHERE u.status=1 AND o.create_time>='2024-01-01' ORDER BY o.create_time DESC;
```

### 4. 注释规范
```sql
-- 查询用户订单信息（包含订单金额统计）
-- 用途：用户中心-订单列表页面
-- 作者：张三
-- 创建时间：2024-01-01
SELECT 
    u.id AS user_id,           -- 用户ID
    u.user_name,               -- 用户姓名
    COUNT(o.id) AS order_count, -- 订单数量
    SUM(o.amount) AS total_amount -- 订单总金额
FROM user_info u
LEFT JOIN order_info o ON u.id = o.user_id 
    AND o.status = 1           -- 只统计有效订单
WHERE u.org_id = #{orgId}      -- 多租户隔离
    AND u.rec_status = 1       -- 有效用户
GROUP BY u.id, u.user_name
HAVING total_amount > 0        -- 只显示有订单的用户
ORDER BY total_amount DESC;
```

### 5. 复杂查询拆分原则
```sql
-- 不推荐：过度复杂的单条查询
SELECT 
    u.id,
    u.user_name,
    (SELECT COUNT(*) FROM order_info WHERE user_id = u.id) AS order_count,
    (SELECT SUM(amount) FROM order_info WHERE user_id = u.id) AS total_amount,
    (SELECT MAX(create_time) FROM order_info WHERE user_id = u.id) AS last_order_time
FROM user_info u
WHERE u.org_id = #{orgId};

-- 推荐：拆分为多个简单查询
-- 步骤1：获取用户基础信息
SELECT id, user_name
FROM user_info 
WHERE org_id = #{orgId} AND rec_status = 1;

-- 步骤2：获取用户订单统计
SELECT 
    user_id,
    COUNT(*) AS order_count,
    SUM(amount) AS total_amount,
    MAX(create_time) AS last_order_time
FROM order_info 
WHERE user_id IN (#{userIds}) AND status = 1
GROUP BY user_id;
```

### 6. 性能优化原则
- 【强制】避免在WHERE条件中使用函数，会导致索引失效
- 【强制】合理使用索引，确保查询条件能命中索引
- 【推荐】使用EXPLAIN分析查询执行计划
- 【推荐】大数据量查询使用分页，避免一次性返回过多数据

### 7. 安全性原则
- 【强制】多租户环境下，所有查询必须包含org_id条件
- 【强制】使用参数化查询，避免SQL注入
- 【强制】敏感数据查询需要权限验证
- 【推荐】重要操作使用事务确保数据一致性

### 8. 维护性原则
- 【强制】SQL语句要有版本控制，记录修改历史
- 【强制】复杂业务逻辑要有详细注释说明
- 【推荐】定期重构复杂SQL，提高可读性
- 【推荐】建立SQL模板库，复用常用查询模式

## 最佳实践示例

### 1. 分页查询模板
```sql
-- 分页查询用户列表
-- 使用主键分页，避免OFFSET性能问题
SELECT 
    id,
    user_name,
    email,
    status,
    create_time
FROM user_info 
WHERE org_id = #{orgId}
    AND rec_status = 1
    AND id > #{lastId}  -- 主键分页
ORDER BY id ASC
LIMIT #{pageSize};
```

### 2. 统计查询模板
```sql
-- 用户活跃度统计
-- 统计最近30天有登录的用户数量
SELECT 
    COUNT(DISTINCT user_id) AS active_users,
    DATE(login_time) AS login_date
FROM user_login_log 
WHERE org_id = #{orgId}
    AND login_time >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY DATE(login_time)
ORDER BY login_date DESC;
```

### 3. 数据更新模板
```sql
-- 批量更新用户状态
-- 更新超过90天未登录的用户为禁用状态
UPDATE user_info 
SET 
    status = 2,  -- 禁用状态
    modify_time = NOW(),
    modify_by = #{operatorId}
WHERE org_id = #{orgId}
    AND status = 1  -- 当前为启用状态
    AND last_login_time < DATE_SUB(NOW(), INTERVAL 90 DAY);
```

## 检查清单

### 代码整洁度检查
- [ ] SQL关键字是否使用大写  
- [ ] 字段名是否使用反引号包围
- [ ] 是否有清晰的缩进和换行
- [ ] 是否有有意义的别名
- [ ] 是否有详细的注释说明

### 可读性检查
- [ ] 小白开发者是否能理解SQL逻辑
- [ ] 复杂查询是否已拆分为简单查询
- [ ] 注释是否说明了业务逻辑
- [ ] 变量名是否具有描述性

### 性能检查
- [ ] 是否避免了索引失效的操作
- [ ] 是否使用了合适的索引
- [ ] 是否避免了全表扫描
- [ ] 大数据量查询是否使用了分页

### 安全性检查
- [ ] 多租户查询是否包含org_id条件
- [ ] 是否使用了参数化查询
- [ ] 是否有权限验证
- [ ] 重要操作是否使用了事务

记住：**整洁的SQL不一定是高效的SQL，但高效的SQL一定是整洁的。让每个看到你SQL的人都能快速理解你的意图。**
description:
globs:
alwaysApply: false
---
