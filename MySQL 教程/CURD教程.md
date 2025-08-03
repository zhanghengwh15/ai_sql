# MySQL CRUD 基础教程

## 目录
- [1. 数据库基础概念](#1-数据库基础概念)
- [2. 连接数据库](#2-连接数据库)
- [3. 数据库操作](#3-数据库操作)
- [4. 表操作](#4-表操作)
- [5. 数据操作（增删改查）](#5-数据操作增删改查)
- [6. 查询进阶](#6-查询进阶)
- [7. 常用函数](#7-常用函数)
- [8. 实际业务场景示例](#8-实际业务场景示例)

## 1. 数据库基础概念

### 1.1 什么是数据库
数据库是存储、管理和检索数据的系统。MySQL是一个关系型数据库管理系统（RDBMS）。

### 1.2 基本概念
- **数据库（Database）**：存储数据的容器
- **表（Table）**：存储具体数据的二维结构
- **字段（Field）**：表中的列
- **记录（Record）**：表中的行
- **主键（Primary Key）**：唯一标识记录的字段

## 2. 连接数据库

### 2.1 命令行连接
```sql
mysql -h 主机名 -u 用户名 -p
```

### 2.2 常用连接参数
- `-h`：主机地址（默认localhost）
- `-u`：用户名
- `-p`：密码
- `-P`：端口号（默认3306）

### 2.3 连接示例
```sql
-- 连接本地数据库
mysql -u root -p

-- 连接远程数据库
mysql -h 192.168.1.100 -u username -p
```

## 3. 数据库操作

### 3.1 查看数据库
```sql
-- 查看所有数据库
SHOW DATABASES;

-- 查看当前数据库
SELECT DATABASE();
```

### 3.2 创建数据库
```sql
-- 创建数据库
CREATE DATABASE database_name;

-- 创建数据库并指定字符集
CREATE DATABASE database_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

### 3.3 使用数据库
```sql
-- 选择数据库
USE database_name;
```

### 3.4 删除数据库
```sql
-- 删除数据库（谨慎使用）
DROP DATABASE database_name;
```

## 4. 表操作

### 4.1 查看表
```sql
-- 查看当前数据库的所有表
SHOW TABLES;

-- 查看表结构
DESCRIBE table_name;
-- 或者
DESC table_name;

-- 查看建表语句
SHOW CREATE TABLE table_name;
```

### 4.2 创建表
```sql
-- 基本建表语法
CREATE TABLE table_name (
    column1 datatype [constraints],
    column2 datatype [constraints],
    ...
);

-- 示例：创建用户表
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    password VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### 4.3 修改表结构
```sql
-- 添加列
ALTER TABLE table_name ADD COLUMN column_name datatype [constraints];

-- 修改列
ALTER TABLE table_name MODIFY COLUMN column_name datatype [constraints];

-- 删除列
ALTER TABLE table_name DROP COLUMN column_name;

-- 重命名表
RENAME TABLE old_name TO new_name;
```

### 4.4 删除表
```sql
-- 删除表（谨慎使用）
DROP TABLE table_name;
```

## 5. 数据操作（增删改查）

### 5.1 插入数据（INSERT）

#### 5.1.1 插入单条记录
```sql
-- 插入所有列
INSERT INTO table_name VALUES (value1, value2, ...);

-- 插入指定列
INSERT INTO table_name (column1, column2, ...) VALUES (value1, value2, ...);

-- 示例
INSERT INTO users (username, email, password) VALUES ('john_doe', 'john@example.com', 'password123');
```

#### 5.1.2 插入多条记录
```sql
-- 插入多条记录
INSERT INTO table_name (column1, column2, ...) VALUES 
    (value1, value2, ...),
    (value1, value2, ...),
    (value1, value2, ...);

-- 示例
INSERT INTO users (username, email, password) VALUES 
    ('alice', 'alice@example.com', 'password123'),
    ('bob', 'bob@example.com', 'password456'),
    ('charlie', 'charlie@example.com', 'password789');
```

### 5.2 查询数据（SELECT）

#### 5.2.1 基本查询
```sql
-- 查询所有列
SELECT * FROM table_name;

-- 查询指定列
SELECT column1, column2, ... FROM table_name;

-- 示例
SELECT id, username, email FROM users;
```

#### 5.2.2 条件查询
```sql
-- 使用WHERE条件
SELECT * FROM table_name WHERE condition;

-- 示例
SELECT * FROM users WHERE username = 'john_doe';
SELECT * FROM users WHERE id > 5;
SELECT * FROM users WHERE email LIKE '%@gmail.com';
```

#### 5.2.3 排序查询
```sql
-- 升序排序（默认）
SELECT * FROM table_name ORDER BY column_name;

-- 降序排序
SELECT * FROM table_name ORDER BY column_name DESC;

-- 多列排序
SELECT * FROM table_name ORDER BY column1 ASC, column2 DESC;

-- 示例
SELECT * FROM users ORDER BY created_at DESC;
```

#### 5.2.4 限制结果数量
```sql
-- 限制返回行数
SELECT * FROM table_name LIMIT number;

-- 分页查询
SELECT * FROM table_name LIMIT offset, number;

-- 示例
SELECT * FROM users LIMIT 10;           -- 前10条
SELECT * FROM users LIMIT 10, 10;       -- 第11-20条
```

### 5.3 更新数据（UPDATE）

#### 5.3.1 基本更新
```sql
-- 更新所有记录
UPDATE table_name SET column1 = value1, column2 = value2;

-- 条件更新
UPDATE table_name SET column1 = value1 WHERE condition;

-- 示例
UPDATE users SET email = 'new_email@example.com' WHERE username = 'john_doe';
UPDATE users SET password = 'new_password' WHERE id = 1;
```

#### 5.3.2 批量更新
```sql
-- 使用CASE语句批量更新
UPDATE users SET 
    status = CASE 
        WHEN id <= 5 THEN 'active'
        WHEN id <= 10 THEN 'inactive'
        ELSE 'pending'
    END
WHERE id <= 15;
```

### 5.4 删除数据（DELETE）

#### 5.4.1 基本删除
```sql
-- 删除所有记录（谨慎使用）
DELETE FROM table_name;

-- 条件删除
DELETE FROM table_name WHERE condition;

-- 示例
DELETE FROM users WHERE username = 'john_doe';
DELETE FROM users WHERE id = 1;
```

#### 5.4.2 安全删除
```sql
-- 删除前先查询确认
SELECT * FROM users WHERE username = 'john_doe';
DELETE FROM users WHERE username = 'john_doe';

-- 限制删除数量
DELETE FROM users WHERE status = 'inactive' LIMIT 10;
```

## 6. 查询进阶

### 6.1 聚合函数
```sql
-- 计数
SELECT COUNT(*) FROM table_name;
SELECT COUNT(column_name) FROM table_name;

-- 求和
SELECT SUM(column_name) FROM table_name;

-- 平均值
SELECT AVG(column_name) FROM table_name;

-- 最大值
SELECT MAX(column_name) FROM table_name;

-- 最小值
SELECT MIN(column_name) FROM table_name;

-- 示例
SELECT COUNT(*) as total_users FROM users;
SELECT AVG(age) as avg_age FROM users WHERE age > 0;
```

### 6.2 分组查询
```sql
-- 基本分组
SELECT column1, COUNT(*) FROM table_name GROUP BY column1;

-- 分组后条件筛选
SELECT column1, COUNT(*) FROM table_name 
GROUP BY column1 
HAVING COUNT(*) > 1;

-- 示例
SELECT status, COUNT(*) as count FROM users GROUP BY status;
```

### 6.3 连接查询
```sql
-- 内连接
SELECT * FROM table1 
INNER JOIN table2 ON table1.id = table2.table1_id;

-- 左连接
SELECT * FROM table1 
LEFT JOIN table2 ON table1.id = table2.table1_id;

-- 右连接
SELECT * FROM table1 
RIGHT JOIN table2 ON table1.id = table2.table1_id;

-- 示例
SELECT u.username, p.name as product_name
FROM users u 
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id;
```

### 6.4 子查询
```sql
-- 在WHERE中使用子查询
SELECT * FROM users 
WHERE id IN (SELECT user_id FROM orders WHERE order_status = 1);

-- 在SELECT中使用子查询
SELECT username, 
       (SELECT COUNT(*) FROM orders WHERE user_id = users.id AND order_status IN (1,2,3)) as order_count 
FROM users;
```

## 7. 常用函数

### 7.1 字符串函数
```sql
-- 连接字符串
SELECT CONCAT(first_name, ' ', last_name) as full_name FROM users;

-- 字符串长度
SELECT LENGTH(username) FROM users;

-- 转大写/小写
SELECT UPPER(username), LOWER(email) FROM users;

-- 截取字符串
SELECT SUBSTRING(email, 1, 5) FROM users;
```

### 7.2 数值函数
```sql
-- 四舍五入
SELECT ROUND(price, 2) FROM products;

-- 向上取整
SELECT CEIL(price) FROM products;

-- 向下取整
SELECT FLOOR(price) FROM products;

-- 绝对值
SELECT ABS(score) FROM scores;
```

### 7.3 日期函数
```sql
-- 当前日期时间
SELECT NOW();
SELECT CURDATE();
SELECT CURTIME();

-- 日期格式化
SELECT DATE_FORMAT(created_at, '%Y-%m-%d') FROM users;

-- 日期计算
SELECT DATE_ADD(created_at, INTERVAL 1 DAY) FROM users;
SELECT DATEDIFF(end_date, start_date) FROM events;
```

### 7.4 条件函数
```sql
-- IF函数
SELECT username, IF(status = 1, 'Active', 'Inactive') as status_text FROM users;

-- CASE语句
SELECT username,
    CASE status
        WHEN 1 THEN 'Active'
        WHEN 0 THEN 'Inactive'
        ELSE 'Unknown'
    END as status_text
FROM users;
```

## 8. 实际业务场景示例

### 8.1 电商系统数据库完整SQL脚本

#### 8.1.1 完整的数据库初始化脚本
```sql
-- ====================================================================
-- 电商系统数据库完整初始化脚本
-- 适用于：MySQL 8.0+
-- 功能：创建数据库、表结构、插入基础数据
-- ====================================================================

-- 1. 创建数据库
DROP DATABASE IF EXISTS ecommerce;
CREATE DATABASE ecommerce CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce;

-- 2. 创建表结构

-- 2.1 用户表（users）
CREATE TABLE users (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '用户ID',
    username VARCHAR(50) NOT NULL COMMENT '用户名',
    email VARCHAR(100) NOT NULL COMMENT '邮箱',
    phone VARCHAR(20) NOT NULL DEFAULT '' COMMENT '手机号',
    password VARCHAR(255) NOT NULL COMMENT '密码',
    real_name VARCHAR(50) NOT NULL DEFAULT '' COMMENT '真实姓名',
    gender TINYINT(4) NOT NULL DEFAULT 0 COMMENT '性别：0-未知，1-男，2-女',
    birthday DATE NULL COMMENT '生日',
    avatar VARCHAR(255) NOT NULL DEFAULT '' COMMENT '头像',
    status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-正常，0-禁用',
    vip_level TINYINT(4) NOT NULL DEFAULT 0 COMMENT 'VIP等级：0-普通，1-银卡，2-金卡，3-钻石',
    points INT(11) NOT NULL DEFAULT 0 COMMENT '积分',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username),
    UNIQUE KEY uk_email (email),
    KEY idx_phone (phone),
    KEY idx_status (status),
    KEY idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 2.2 商品分类表（categories）
CREATE TABLE categories (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '分类ID',
    parent_id BIGINT(20) UNSIGNED NOT NULL DEFAULT 0 COMMENT '父分类ID',
    name VARCHAR(100) NOT NULL COMMENT '分类名称',
    description TEXT NULL COMMENT '分类描述',
    icon VARCHAR(255) NOT NULL DEFAULT '' COMMENT '分类图标',
    sort_order INT(11) NOT NULL DEFAULT 0 COMMENT '排序',
    status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-启用，0-禁用',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
    PRIMARY KEY (id),
    KEY idx_parent_id (parent_id),
    KEY idx_status (status),
    KEY idx_sort_order (sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品分类表';

-- 2.3 商品表（products）
CREATE TABLE products (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '商品ID',
    category_id BIGINT(20) UNSIGNED NOT NULL COMMENT '分类ID',
    name VARCHAR(200) NOT NULL COMMENT '商品名称',
    description TEXT NULL COMMENT '商品描述',
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '商品价格',
    original_price DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '原价',
    stock INT(11) NOT NULL DEFAULT 0 COMMENT '库存',
    sales_count INT(11) NOT NULL DEFAULT 0 COMMENT '销量',
    view_count INT(11) NOT NULL DEFAULT 0 COMMENT '浏览量',
    main_image VARCHAR(255) NOT NULL DEFAULT '' COMMENT '主图',
    images TEXT NULL COMMENT '商品图片，JSON格式',
    status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '状态：1-上架，0-下架',
    is_hot TINYINT(4) NOT NULL DEFAULT 0 COMMENT '是否热销：1-是，0-否',
    is_recommend TINYINT(4) NOT NULL DEFAULT 0 COMMENT '是否推荐：1-是，0-否',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
    PRIMARY KEY (id),
    KEY idx_category_id (category_id),
    KEY idx_status (status),
    KEY idx_price (price),
    KEY idx_sales_count (sales_count),
    KEY idx_create_time (create_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品表';

-- 2.4 订单表（orders）
CREATE TABLE orders (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单ID',
    order_no VARCHAR(50) NOT NULL COMMENT '订单号',
    user_id BIGINT(20) UNSIGNED NOT NULL COMMENT '用户ID',
    total_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '订单总金额',
    discount_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '优惠金额',
    pay_amount DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '实付金额',
    pay_method TINYINT(4) NOT NULL DEFAULT 0 COMMENT '支付方式：1-支付宝，2-微信，3-银行卡',
    pay_time DATETIME NULL COMMENT '支付时间',
    order_status TINYINT(4) NOT NULL DEFAULT 0 COMMENT '订单状态：0-待付款，1-已付款，2-已发货，3-已完成，4-已取消',
    shipping_address TEXT NOT NULL COMMENT '收货地址',
    shipping_name VARCHAR(50) NOT NULL COMMENT '收货人姓名',
    shipping_phone VARCHAR(20) NOT NULL COMMENT '收货人电话',
    shipping_company VARCHAR(50) NOT NULL DEFAULT '' COMMENT '快递公司',
    shipping_no VARCHAR(50) NOT NULL DEFAULT '' COMMENT '快递单号',
    remark VARCHAR(500) NOT NULL DEFAULT '' COMMENT '订单备注',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
    PRIMARY KEY (id),
    UNIQUE KEY uk_order_no (order_no),
    KEY idx_user_id (user_id),
    KEY idx_order_status (order_status),
    KEY idx_create_time (create_time),
    KEY idx_pay_time (pay_time)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

-- 2.5 订单详情表（order_items）
CREATE TABLE order_items (
    id BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '订单项ID',
    order_id BIGINT(20) UNSIGNED NOT NULL COMMENT '订单ID',
    product_id BIGINT(20) UNSIGNED NOT NULL COMMENT '商品ID',
    product_name VARCHAR(200) NOT NULL COMMENT '商品名称',
    product_image VARCHAR(255) NOT NULL DEFAULT '' COMMENT '商品图片',
    price DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '商品单价',
    quantity INT(11) NOT NULL DEFAULT 1 COMMENT '购买数量',
    total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00 COMMENT '小计金额',
    create_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    modify_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '修改时间',
    rec_status TINYINT(4) NOT NULL DEFAULT 1 COMMENT '记录状态：1-有效，0-删除',
    PRIMARY KEY (id),
    KEY idx_order_id (order_id),
    KEY idx_product_id (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单详情表';

-- 3. 插入基础数据

-- 3.1 插入用户数据（按ID顺序插入，确保ID与后续示例数据一致）
INSERT INTO users (id, username, email, phone, password, real_name, gender, birthday, avatar, status, vip_level, points) VALUES 
(1, 'zhang_san', 'zhangsan@example.com', '13800138001', 'password123', '张三', 1, '1990-01-15', 'avatar1.jpg', 1, 1, 500),
(2, 'li_si', 'lisi@example.com', '13800138002', 'password456', '李四', 2, '1988-05-20', 'avatar2.jpg', 1, 2, 1200),
(3, 'wang_wu', 'wangwu@example.com', '13800138003', 'password789', '王五', 1, '1992-08-10', 'avatar3.jpg', 1, 0, 200),
(4, 'zhao_liu', 'zhaoliu@example.com', '13800138004', 'password101', '赵六', 2, '1995-12-25', 'avatar4.jpg', 1, 3, 3000),
(5, 'sun_qi', 'sunqi@example.com', '13800138005', 'password202', '孙七', 1, '1985-03-08', 'avatar5.jpg', 0, 1, 800);

-- 3.2 插入商品分类数据（按ID顺序插入）
INSERT INTO categories (id, parent_id, name, description, icon, sort_order, status) VALUES 
(1, 0, '电子产品', '各类电子产品', 'electronics.png', 1, 1),
(2, 0, '服装鞋帽', '时尚服装和鞋帽', 'clothing.png', 2, 1),
(3, 0, '家居用品', '家居生活用品', 'home.png', 3, 1),
(4, 1, '手机数码', '手机、平板等数码产品', 'mobile.png', 1, 1),
(5, 1, '电脑办公', '电脑、办公设备', 'computer.png', 2, 1),
(6, 2, '男装', '男士服装', 'men.png', 1, 1),
(7, 2, '女装', '女士服装', 'women.png', 2, 1),
(8, 3, '厨房用品', '厨房相关用品', 'kitchen.png', 1, 1),
(9, 3, '清洁用品', '清洁相关用品', 'cleaning.png', 2, 1);

-- 3.3 插入商品数据（按ID顺序插入）
INSERT INTO products (id, category_id, name, description, price, original_price, stock, sales_count, view_count, main_image, status, is_hot, is_recommend) VALUES 
(1, 4, 'iPhone 15 Pro', '苹果最新旗舰手机，搭载A17 Pro芯片', 8999.00, 9999.00, 100, 50, 2000, 'iphone15.jpg', 1, 1, 1),
(2, 4, '华为 Mate 60 Pro', '华为旗舰手机，支持卫星通信', 6999.00, 7999.00, 80, 30, 1500, 'mate60.jpg', 1, 1, 1),
(3, 5, 'MacBook Pro 14', '苹果专业级笔记本电脑', 14999.00, 15999.00, 50, 20, 800, 'macbook.jpg', 1, 0, 1),
(4, 5, '联想 ThinkPad X1', '商务笔记本电脑', 8999.00, 9999.00, 60, 25, 600, 'thinkpad.jpg', 1, 0, 0),
(5, 6, '男士休闲夹克', '时尚休闲男士夹克', 299.00, 399.00, 200, 150, 3000, 'jacket.jpg', 1, 1, 0),
(6, 7, '女士连衣裙', '优雅女士连衣裙', 199.00, 299.00, 150, 200, 2500, 'dress.jpg', 1, 1, 1),
(7, 8, '多功能料理机', '家用多功能料理机', 599.00, 699.00, 80, 40, 1200, 'blender.jpg', 1, 0, 1),
(8, 9, '智能扫地机器人', '全自动智能扫地机器人', 1299.00, 1499.00, 60, 35, 1800, 'robot.jpg', 1, 1, 1);

-- 3.4 插入订单数据（按ID顺序插入）
INSERT INTO orders (id, order_no, user_id, total_amount, discount_amount, pay_amount, pay_method, pay_time, order_status, shipping_address, shipping_name, shipping_phone) VALUES 
(1, 'ORD20240101001', 1, 8999.00, 500.00, 8499.00, 1, '2024-01-01 10:30:00', 3, '北京市朝阳区某某街道123号', '张三', '13800138001'),
(2, 'ORD20240102001', 2, 299.00, 50.00, 249.00, 2, '2024-01-02 14:20:00', 2, '上海市浦东新区某某路456号', '李四', '13800138002'),
(3, 'ORD20240103001', 3, 599.00, 0.00, 599.00, 1, '2024-01-03 09:15:00', 1, '广州市天河区某某大道789号', '王五', '13800138003'),
(4, 'ORD20240104001', 4, 1299.00, 100.00, 1199.00, 2, '2024-01-04 16:45:00', 0, '深圳市南山区某某街321号', '赵六', '13800138004'),
(5, 'ORD20240105001', 1, 199.00, 20.00, 179.00, 1, NULL, 0, '北京市朝阳区某某街道123号', '张三', '13800138001');

-- 3.5 插入订单详情数据（按ID顺序插入）
INSERT INTO order_items (id, order_id, product_id, product_name, product_image, price, quantity, total_price) VALUES 
(1, 1, 1, 'iPhone 15 Pro', 'iphone15.jpg', 8999.00, 1, 8999.00),
(2, 2, 5, '男士休闲夹克', 'jacket.jpg', 299.00, 1, 299.00),
(3, 3, 7, '多功能料理机', 'blender.jpg', 599.00, 1, 599.00),
(4, 4, 8, '智能扫地机器人', 'robot.jpg', 1299.00, 1, 1299.00),
(5, 5, 6, '女士连衣裙', 'dress.jpg', 199.00, 1, 199.00);

-- 4. 重置自增ID，确保后续插入数据的ID从下一个值开始
ALTER TABLE users AUTO_INCREMENT = 6;
ALTER TABLE categories AUTO_INCREMENT = 10;
ALTER TABLE products AUTO_INCREMENT = 9;
ALTER TABLE orders AUTO_INCREMENT = 6;
ALTER TABLE order_items AUTO_INCREMENT = 6;

-- 5. 验证数据插入结果
SELECT '用户表数据验证：' as info;
SELECT id, username, real_name, status, vip_level, points FROM users ORDER BY id;

SELECT '商品分类数据验证：' as info;
SELECT id, parent_id, name, status FROM categories ORDER BY id;

SELECT '商品数据验证：' as info;
SELECT id, category_id, name, price, stock, sales_count FROM products ORDER BY id;

SELECT '订单数据验证：' as info;
SELECT id, order_no, user_id, total_amount, pay_amount, order_status FROM orders ORDER BY id;

SELECT '订单详情数据验证：' as info;
SELECT id, order_id, product_id, product_name, price, quantity FROM order_items ORDER BY id;

-- ====================================================================
-- 初始化脚本执行完成
-- 数据库：ecommerce
-- 表数量：5个
-- 用户数据：5条
-- 商品分类：9条
-- 商品数据：8条
-- 订单数据：5条
-- 订单详情：5条
-- ====================================================================
```

### 8.2 基于基础数据的查询示例（按功能分类）

#### 8.2.1 基础查询示例

**示例1：查询所有正常状态的用户信息**
```sql
-- 基于基础数据：应返回4条记录（张三、李四、王五、赵六）
SELECT id, username, email, real_name, gender, vip_level, points, create_time 
FROM users 
WHERE status = 1 
ORDER BY create_time DESC;

-- 预期结果：
-- id=4, username=zhao_liu, real_name=赵六, vip_level=3, points=3000
-- id=3, username=wang_wu, real_name=王五, vip_level=0, points=200  
-- id=2, username=li_si, real_name=李四, vip_level=2, points=1200
-- id=1, username=zhang_san, real_name=张三, vip_level=1, points=500
```

**示例2：查询商品分类及其子分类**
```sql
-- 基于基础数据：应返回6条记录（3个一级分类，各有2个子分类）
SELECT c1.name as parent_category, c2.name as sub_category, c2.description
FROM categories c1
INNER JOIN categories c2 ON c1.id = c2.parent_id
WHERE c1.parent_id = 0 AND c1.status = 1 AND c2.status = 1
ORDER BY c1.sort_order, c2.sort_order;

-- 预期结果：
-- parent_category=电子产品, sub_category=手机数码
-- parent_category=电子产品, sub_category=电脑办公
-- parent_category=服装鞋帽, sub_category=男装
-- parent_category=服装鞋帽, sub_category=女装
-- parent_category=家居用品, sub_category=厨房用品
-- parent_category=家居用品, sub_category=清洁用品
```

**示例3：查询热销商品**
```sql
-- 基于基础数据：应返回5条记录（is_hot=1的商品）
SELECT id, name, price, original_price, stock, sales_count, view_count, main_image
FROM products 
WHERE status = 1 AND is_hot = 1
ORDER BY sales_count DESC, view_count DESC
LIMIT 10;

-- 预期结果：
-- id=5, name=男士休闲夹克, sales_count=150, view_count=3000
-- id=6, name=女士连衣裙, sales_count=200, view_count=2500
-- id=1, name=iPhone 15 Pro, sales_count=50, view_count=2000
-- id=8, name=智能扫地机器人, sales_count=35, view_count=1800
-- id=2, name=华为 Mate 60 Pro, sales_count=30, view_count=1500
```

#### 8.2.2 条件查询示例

**示例4：查询指定价格区间的商品**
```sql
-- 基于基础数据：查询100-1000元价位的商品，应返回3条记录
SELECT id, name, price, original_price, stock, sales_count
FROM products 
WHERE status = 1 
  AND price BETWEEN 100 AND 1000
  AND stock > 0
ORDER BY price ASC;

-- 预期结果：
-- id=6, name=女士连衣裙, price=199.00, stock=150
-- id=5, name=男士休闲夹克, price=299.00, stock=200
-- id=7, name=多功能料理机, price=599.00, stock=80
```

**示例5：查询VIP用户**
```sql
-- 基于基础数据：应返回3条记录（张三银卡、李四金卡、赵六钻石）
SELECT id, username, real_name, vip_level, points, create_time
FROM users 
WHERE status = 1 AND vip_level > 0
ORDER BY vip_level DESC, points DESC;

-- 预期结果：
-- id=4, username=zhao_liu, real_name=赵六, vip_level=3, points=3000
-- id=2, username=li_si, real_name=李四, vip_level=2, points=1200
-- id=1, username=zhang_san, real_name=张三, vip_level=1, points=500
```

**示例6：查询待付款订单**
```sql
-- 基于基础数据：应返回2条记录（订单4和订单5都是待付款状态）
SELECT o.id, o.order_no, u.username, u.real_name, o.total_amount, o.pay_amount, o.create_time
FROM orders o
INNER JOIN users u ON o.user_id = u.id
WHERE o.order_status = 0
ORDER BY o.create_time ASC;

-- 预期结果：
-- id=4, order_no=ORD20240104001, username=zhao_liu, real_name=赵六, total_amount=1299.00
-- id=5, order_no=ORD20240105001, username=zhang_san, real_name=张三, total_amount=199.00
```

#### 8.2.3 聚合查询示例

**示例7：统计各一级分类下的商品数量**
```sql
-- 基于基础数据：统计电子产品、服装鞋帽、家居用品各有多少商品
SELECT 
    c.name as category_name, 
    COUNT(p.id) as product_count,
    AVG(p.price) as avg_price
FROM categories c
LEFT JOIN products p ON c.id = p.category_id AND p.status = 1
WHERE c.status = 1 AND c.parent_id = 0
GROUP BY c.id, c.name
ORDER BY product_count DESC;

-- 预期结果：
-- category_name=电子产品, product_count=4, avg_price=9749.25 (iPhone+华为+MacBook+ThinkPad)
-- category_name=服装鞋帽, product_count=2, avg_price=249.00 (夹克+连衣裙)
-- category_name=家居用品, product_count=2, avg_price=949.00 (料理机+扫地机器人)
```

**示例8：统计用户消费情况**
```sql
-- 基于基础数据：统计已完成订单的用户消费情况
SELECT 
    u.username,
    u.real_name,
    u.vip_level,
    COUNT(o.id) as order_count,
    COALESCE(SUM(o.pay_amount), 0) as total_spent,
    COALESCE(AVG(o.pay_amount), 0) as avg_order_amount
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.order_status IN (1,2,3)
WHERE u.status = 1
GROUP BY u.id, u.username, u.real_name, u.vip_level
ORDER BY total_spent DESC;

-- 预期结果：
-- username=zhang_san, real_name=张三, order_count=1, total_spent=8499.00
-- username=li_si, real_name=李四, order_count=1, total_spent=249.00
-- username=wang_wu, real_name=王五, order_count=1, total_spent=599.00
-- username=zhao_liu, real_name=赵六, order_count=0, total_spent=0 (待付款订单不计算)
```

**示例9：统计商品销量排行**
```sql
-- 基于基础数据：按销量和转化率排序
SELECT 
    p.id,
    p.name,
    p.price,
    p.sales_count,
    p.view_count,
    CASE 
        WHEN p.view_count > 0 THEN ROUND(p.sales_count / p.view_count * 100, 2)
        ELSE 0 
    END as conversion_rate
FROM products p
WHERE p.status = 1 AND p.sales_count > 0
ORDER BY p.sales_count DESC, conversion_rate DESC
LIMIT 5;

-- 预期结果：
-- id=6, name=女士连衣裙, sales_count=200, conversion_rate=8.00%
-- id=5, name=男士休闲夹克, sales_count=150, conversion_rate=5.00%
-- id=1, name=iPhone 15 Pro, sales_count=50, conversion_rate=2.50%
-- id=7, name=多功能料理机, sales_count=40, conversion_rate=3.33%
-- id=8, name=智能扫地机器人, sales_count=35, conversion_rate=1.94%
```

#### 8.2.4 连接查询示例

**示例10：查询所有订单详情（含用户和商品信息）**
```sql
-- 基于基础数据：应返回5条记录，每条记录包含订单、用户、商品信息
SELECT 
    o.id as order_id,
    o.order_no,
    u.username,
    u.real_name,
    o.total_amount,
    o.pay_amount,
    CASE o.order_status 
        WHEN 0 THEN '待付款'
        WHEN 1 THEN '已付款'
        WHEN 2 THEN '已发货'
        WHEN 3 THEN '已完成'
        WHEN 4 THEN '已取消'
    END as status_name,
    oi.product_name,
    oi.price,
    oi.quantity,
    o.create_time
FROM orders o
INNER JOIN users u ON o.user_id = u.id
INNER JOIN order_items oi ON o.id = oi.order_id
WHERE o.rec_status = 1
ORDER BY o.create_time DESC;

-- 预期结果：
-- order_id=5, order_no=ORD20240105001, username=zhang_san, product_name=女士连衣裙, status_name=待付款
-- order_id=4, order_no=ORD20240104001, username=zhao_liu, product_name=智能扫地机器人, status_name=待付款
-- order_id=3, order_no=ORD20240103001, username=wang_wu, product_name=多功能料理机, status_name=已付款
-- order_id=2, order_no=ORD20240102001, username=li_si, product_name=男士休闲夹克, status_name=已发货
-- order_id=1, order_no=ORD20240101001, username=zhang_san, product_name=iPhone 15 Pro, status_name=已完成
```

**示例11：查询张三的购买历史**
```sql
-- 基于基础数据：张三(user_id=1)购买了iPhone 15 Pro和女士连衣裙
SELECT 
    u.username,
    u.real_name,
    p.name as product_name,
    c.name as category_name,
    oi.price,
    oi.quantity,
    oi.total_price,
    CASE o.order_status 
        WHEN 0 THEN '待付款'
        WHEN 1 THEN '已付款'
        WHEN 2 THEN '已发货'
        WHEN 3 THEN '已完成'
        WHEN 4 THEN '已取消'
    END as status_name,
    o.create_time
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
INNER JOIN products p ON oi.product_id = p.id
INNER JOIN categories c ON p.category_id = c.id
WHERE u.username = 'zhang_san' AND o.rec_status = 1
ORDER BY o.create_time DESC;

-- 预期结果：
-- product_name=女士连衣裙, category_name=女装, price=199.00, status_name=待付款
-- product_name=iPhone 15 Pro, category_name=手机数码, price=8999.00, status_name=已完成
```

**示例12：查询商品及其分类和销售情况**
```sql
-- 基于基础数据：查询所有商品的分类和销售统计
SELECT 
    p.id,
    p.name as product_name,
    c1.name as main_category,
    c2.name as sub_category,
    p.price,
    p.stock,
    p.sales_count,
    COALESCE(order_stats.order_count, 0) as order_count,
    COALESCE(order_stats.total_sales_amount, 0) as total_sales_amount
FROM products p
INNER JOIN categories c2 ON p.category_id = c2.id
INNER JOIN categories c1 ON c2.parent_id = c1.id
LEFT JOIN (
    SELECT 
        oi.product_id,
        COUNT(DISTINCT oi.order_id) as order_count,
        SUM(oi.total_price) as total_sales_amount
    FROM order_items oi
    INNER JOIN orders o ON oi.order_id = o.id
    WHERE o.order_status IN (1,2,3)  -- 只统计已付款及以上状态的订单
    GROUP BY oi.product_id
) order_stats ON p.id = order_stats.product_id
WHERE p.status = 1
ORDER BY order_stats.total_sales_amount DESC;

-- 预期结果：前几名商品的实际销售情况
-- iPhone 15 Pro: 主分类=电子产品, 子分类=手机数码, order_count=1, total_sales_amount=8999.00
-- 多功能料理机: 主分类=家居用品, 子分类=厨房用品, order_count=1, total_sales_amount=599.00
-- 男士休闲夹克: 主分类=服装鞋帽, 子分类=男装, order_count=1, total_sales_amount=299.00
```

#### 8.2.5 子查询示例

**示例13：查询购买过iPhone的用户**
```sql
-- 基于基础数据：只有张三购买过iPhone 15 Pro
SELECT DISTINCT 
    u.id, 
    u.username, 
    u.real_name, 
    u.email,
    u.vip_level,
    u.points
FROM users u
INNER JOIN orders o ON u.id = o.user_id
INNER JOIN order_items oi ON o.id = oi.order_id
WHERE oi.product_id IN (
    SELECT id FROM products WHERE name LIKE '%iPhone%' AND status = 1
)
AND u.status = 1
AND o.order_status IN (1,2,3);  -- 只统计已付款的订单

-- 预期结果：
-- id=1, username=zhang_san, real_name=张三, email=zhangsan@example.com, vip_level=1, points=500
```

**示例14：查询消费金额超过平均值的用户**
```sql
-- 基于基础数据：计算已完成订单用户的平均消费，找出高消费用户
SELECT 
    u.username, 
    u.real_name, 
    u.vip_level,
    SUM(o.pay_amount) as total_spent,
    COUNT(o.id) as order_count
FROM users u
INNER JOIN orders o ON u.id = o.user_id
WHERE o.order_status IN (1,2,3) AND u.status = 1
GROUP BY u.id, u.username, u.real_name, u.vip_level
HAVING total_spent > (
    -- 子查询：计算所有用户的平均消费金额
    SELECT AVG(user_total) FROM (
        SELECT SUM(o2.pay_amount) as user_total
        FROM users u2
        INNER JOIN orders o2 ON u2.id = o2.user_id
        WHERE o2.order_status IN (1,2,3) AND u2.status = 1
        GROUP BY u2.id
    ) as avg_table
)
ORDER BY total_spent DESC;

-- 预期结果分析：
-- 基础数据中已完成订单的消费金额：张三=8499.00, 李四=249.00, 王五=599.00
-- 平均消费：(8499.00 + 249.00 + 599.00) / 3 = 3115.67
-- 超过平均值的用户：张三(8499.00)
```

**示例15：查询同分类下价格高于平均价格的商品**
```sql
-- 基于基础数据：查询各子分类中价格高于该分类平均价格的商品
SELECT 
    p.id,
    p.name,
    c.name as category_name,
    p.price,
    (SELECT AVG(p2.price) 
     FROM products p2 
     WHERE p2.category_id = p.category_id AND p2.status = 1) as avg_category_price
FROM products p
INNER JOIN categories c ON p.category_id = c.id
WHERE p.status = 1
AND p.price > (
    SELECT AVG(p3.price) 
    FROM products p3 
    WHERE p3.category_id = p.category_id AND p3.status = 1
)
ORDER BY p.category_id, p.price DESC;

-- 预期结果分析：
-- 手机数码分类：iPhone 15 Pro(8999) > 华为 Mate 60 Pro(6999)，平均价7999，iPhone高于平均
-- 电脑办公分类：MacBook Pro 14(14999) > ThinkPad X1(8999)，平均价11999，MacBook高于平均
-- 其他分类只有1-2个商品，可能无高于平均价格的商品
```

### 8.3 基于基础数据的更新示例

#### 8.3.1 商品价格更新示例

**示例16：手机数码分类商品统一涨价10%**
```sql
-- 基于基础数据：影响iPhone 15 Pro和华为 Mate 60 Pro
UPDATE products 
SET price = ROUND(price * 1.1, 2), 
    modify_time = CURRENT_TIMESTAMP
WHERE category_id = 4 AND status = 1;

-- 更新前后对比：
-- iPhone 15 Pro: 8999.00 -> 9898.90
-- 华为 Mate 60 Pro: 6999.00 -> 7698.90

-- 验证更新结果
SELECT id, name, price, original_price 
FROM products 
WHERE category_id = 4 AND status = 1;
```

**示例17：批量更新商品推荐状态**
```sql
-- 基于基础数据：将销量超过100的商品设置为推荐商品
UPDATE products 
SET is_recommend = 1,
    modify_time = CURRENT_TIMESTAMP
WHERE sales_count > 100 AND status = 1;

-- 影响的商品：男士休闲夹克(150)、女士连衣裙(200)

-- 验证更新结果
SELECT id, name, sales_count, is_recommend 
FROM products 
WHERE sales_count > 100;
```

#### 8.3.2 用户积分更新示例

**示例18：根据消费金额给VIP用户增加积分**
```sql
-- 基于基础数据：根据已完成订单消费金额，按10:1比例增加积分
UPDATE users u
SET points = points + COALESCE((
    SELECT FLOOR(SUM(o.pay_amount) / 10)
    FROM orders o
    WHERE o.user_id = u.id 
    AND o.order_status IN (1,2,3)
    AND o.create_time >= '2024-01-01'
), 0),
modify_time = CURRENT_TIMESTAMP
WHERE u.status = 1 AND u.vip_level > 0;

-- 影响的用户：
-- 张三(VIP银卡): 原积分500 + 849 = 1349 (8499/10)
-- 李四(VIP金卡): 原积分1200 + 24 = 1224 (249/10)
-- 赵六(VIP钻石): 原积分3000 + 0 = 3000 (无已完成订单)

-- 验证更新结果
SELECT username, real_name, vip_level, points
FROM users 
WHERE status = 1 AND vip_level > 0
ORDER BY vip_level DESC;
```

**示例19：用户生日月份积分翻倍**
```sql
-- 基于基础数据：给当前月份过生日的用户积分翻倍
UPDATE users 
SET points = points * 2,
    modify_time = CURRENT_TIMESTAMP
WHERE status = 1 
AND MONTH(birthday) = MONTH(CURRENT_DATE())
AND DAY(birthday) >= DAY(CURRENT_DATE());

-- 注意：需要根据当前实际月份确定影响的用户
-- 如果当前是1月份，则影响张三(1990-01-15)
```

#### 8.3.3 订单状态更新示例

**示例20：自动取消超时未付款订单**
```sql
-- 基于基础数据：将创建超过7天且仍未付款的订单自动取消
UPDATE orders 
SET order_status = 4,  -- 4表示已取消
    remark = CONCAT(COALESCE(remark, ''), ' [系统自动取消：超时未付款]'),
    modify_time = CURRENT_TIMESTAMP
WHERE order_status = 0 
AND create_time < DATE_SUB(NOW(), INTERVAL 7 DAY);

-- 基于基础数据的订单创建时间（2024年1月），如果当前时间超过2024-01-11，
-- 则订单4和订单5会被取消

-- 验证更新结果
SELECT id, order_no, order_status, create_time, remark
FROM orders 
WHERE order_status = 4;
```

**示例21：批量发货处理**
```sql
-- 基于基础数据：将已付款状态的订单批量设置为已发货
UPDATE orders 
SET order_status = 2,  -- 2表示已发货
    shipping_company = '顺丰快递',
    shipping_no = CONCAT('SF', LPAD(id * 1000 + 12345, 12, '0')),
    modify_time = CURRENT_TIMESTAMP
WHERE order_status = 1;

-- 影响的订单：订单3(王五的多功能料理机)
-- 快递单号将生成为：SF000003012345

-- 验证更新结果
SELECT id, order_no, order_status, shipping_company, shipping_no
FROM orders 
WHERE order_status = 2;
```

### 8.4 基于基础数据的删除示例

#### 8.4.1 安全删除示例

**示例22：删除已取消的订单详情**
```sql
-- 第一步：查看要删除的数据
SELECT oi.id, oi.product_name, o.order_no, o.order_status
FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.order_status = 4;  -- 4表示已取消

-- 第二步：执行删除（如果有已取消的订单）
DELETE oi FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.order_status = 4;

-- 注意：基础数据中没有已取消的订单，此删除不会影响任何数据
```

**示例23：清理无效的商品图片记录**
```sql
-- 基于基础数据：删除图片字段为空且状态为下架的商品
-- 第一步：查看要删除的数据
SELECT id, name, main_image, status
FROM products 
WHERE (main_image = '' OR main_image IS NULL)
AND status = 0;

-- 第二步：执行删除
DELETE FROM products 
WHERE (main_image = '' OR main_image IS NULL)
AND status = 0
AND create_time < DATE_SUB(CURRENT_DATE, INTERVAL 30 DAY);

-- 注意：基础数据中所有商品都有main_image且status=1，此删除不会影响任何数据
```

#### 8.4.2 批量删除示例

**示例24：删除指定用户的购物车数据（假设有购物车表）**
```sql
-- 假设存在购物车表 cart，删除已禁用用户的购物车数据
/*
DELETE c FROM cart c
INNER JOIN users u ON c.user_id = u.id
WHERE u.status = 0;
*/

-- 基于基础数据：孙七(id=5)是禁用状态，如果有购物车表，则删除其购物车数据
-- 注意：此处为演示语法，实际基础数据中没有购物车表
```

**示例25：数据清理和归档**
```sql
-- 删除2023年之前的测试订单数据（仅在测试环境使用）
-- 第一步：确认要删除的订单
SELECT COUNT(*) as total_orders
FROM orders 
WHERE create_time < '2024-01-01' 
AND order_no LIKE 'TEST%';

-- 第二步：删除订单详情
DELETE oi FROM order_items oi
INNER JOIN orders o ON oi.order_id = o.id
WHERE o.create_time < '2024-01-01' 
AND o.order_no LIKE 'TEST%';

-- 第三步：删除订单
DELETE FROM orders 
WHERE create_time < '2024-01-01' 
AND order_no LIKE 'TEST%';

-- 注意：基础数据中的订单号都是ORD开头，不会被删除
```

#### 8.4.3 删除验证和回滚

**示例26：安全删除流程示例**
```sql
-- 安全删除流程：以删除禁用用户为例

-- 第一步：开启事务
START TRANSACTION;

-- 第二步：查看要删除的数据
SELECT id, username, real_name, status, create_time
FROM users 
WHERE status = 0;

-- 第三步：备份要删除的数据到临时表
CREATE TEMPORARY TABLE users_backup AS
SELECT * FROM users WHERE status = 0;

-- 第四步：执行删除
DELETE FROM users WHERE status = 0;

-- 第五步：验证删除结果
SELECT COUNT(*) as remaining_disabled_users
FROM users 
WHERE status = 0;

-- 第六步：确认删除 或 回滚
-- 如果确认删除：COMMIT;
-- 如果需要回滚：ROLLBACK;

-- 基于基础数据：会删除孙七(id=5, status=0)这一条记录
COMMIT;  -- 或 ROLLBACK;
```

### 8.5 基础数据验证和测试

#### 8.5.1 数据完整性验证
```sql
-- 验证基础数据的完整性和一致性

-- 1. 验证用户数据
SELECT 
    '用户数据验证' as check_type,
    COUNT(*) as total_count,
    SUM(CASE WHEN status = 1 THEN 1 ELSE 0 END) as active_count,
    SUM(CASE WHEN vip_level > 0 THEN 1 ELSE 0 END) as vip_count
FROM users;

-- 2. 验证商品分类层级关系
SELECT 
    '分类层级验证' as check_type,
    SUM(CASE WHEN parent_id = 0 THEN 1 ELSE 0 END) as main_categories,
    SUM(CASE WHEN parent_id > 0 THEN 1 ELSE 0 END) as sub_categories,
    COUNT(*) as total_categories
FROM categories;

-- 3. 验证商品与分类的关联
SELECT 
    '商品分类关联验证' as check_type,
    COUNT(DISTINCT p.category_id) as linked_categories,
    COUNT(*) as total_products,
    MIN(p.price) as min_price,
    MAX(p.price) as max_price
FROM products p
INNER JOIN categories c ON p.category_id = c.id;

-- 4. 验证订单数据完整性
SELECT 
    '订单数据验证' as check_type,
    COUNT(*) as total_orders,
    COUNT(DISTINCT user_id) as unique_customers,
    SUM(total_amount) as total_order_amount,
    SUM(pay_amount) as total_pay_amount,
    AVG(pay_amount) as avg_order_value
FROM orders;

-- 5. 验证订单详情与订单的一致性
SELECT 
    '订单详情一致性验证' as check_type,
    COUNT(oi.id) as total_items,
    COUNT(DISTINCT oi.order_id) as orders_with_items,
    SUM(oi.total_price) as items_total_amount,
    CASE 
        WHEN ABS(SUM(oi.total_price) - (SELECT SUM(total_amount) FROM orders)) < 0.01 
        THEN '一致' 
        ELSE '不一致' 
    END as amount_consistency
FROM order_items oi;
```

#### 8.5.2 业务规则验证
```sql
-- 验证业务规则的合理性

-- 1. 验证价格合理性
SELECT 
    '价格合理性检查' as check_type,
    COUNT(*) as total_products,
    SUM(CASE WHEN price <= original_price THEN 1 ELSE 0 END) as reasonable_price_count,
    SUM(CASE WHEN price > original_price THEN 1 ELSE 0 END) as invalid_price_count
FROM products
WHERE status = 1;

-- 2. 验证库存合理性
SELECT 
    '库存合理性检查' as check_type,
    COUNT(*) as total_products,
    SUM(CASE WHEN stock >= 0 THEN 1 ELSE 0 END) as valid_stock_count,
    SUM(CASE WHEN stock < 0 THEN 1 ELSE 0 END) as invalid_stock_count,
    AVG(stock) as avg_stock
FROM products
WHERE status = 1;

-- 3. 验证订单状态合理性
SELECT 
    '订单状态检查' as check_type,
    order_status,
    CASE order_status
        WHEN 0 THEN '待付款'
        WHEN 1 THEN '已付款'
        WHEN 2 THEN '已发货'
        WHEN 3 THEN '已完成'
        WHEN 4 THEN '已取消'
        ELSE '未知状态'
    END as status_name,
    COUNT(*) as count,
    SUM(total_amount) as total_amount
FROM orders
GROUP BY order_status
ORDER BY order_status;

-- 4. 验证用户VIP等级与积分的合理性
SELECT 
    '用户VIP等级检查' as check_type,
    vip_level,
    CASE vip_level
        WHEN 0 THEN '普通用户'
        WHEN 1 THEN '银卡会员'
        WHEN 2 THEN '金卡会员'
        WHEN 3 THEN '钻石会员'
        ELSE '未知等级'
    END as level_name,
    COUNT(*) as user_count,
    AVG(points) as avg_points,
    MIN(points) as min_points,
    MAX(points) as max_points
FROM users
WHERE status = 1
GROUP BY vip_level
ORDER BY vip_level;
```

#### 8.5.3 性能测试查询
```sql
-- 测试查询性能的示例

-- 1. 复杂连接查询性能测试
EXPLAIN SELECT 
    u.username,
    u.real_name,
    COUNT(o.id) as order_count,
    SUM(o.pay_amount) as total_spent,
    GROUP_CONCAT(DISTINCT c.name SEPARATOR ', ') as purchased_categories
FROM users u
LEFT JOIN orders o ON u.id = o.user_id AND o.order_status IN (1,2,3)
LEFT JOIN order_items oi ON o.id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.id
LEFT JOIN categories c ON p.category_id = c.id
WHERE u.status = 1
GROUP BY u.id, u.username, u.real_name
ORDER BY total_spent DESC;

-- 2. 子查询性能测试
EXPLAIN SELECT 
    p.name,
    p.price,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.product_id = p.id) as order_count,
    (SELECT AVG(price) FROM products p2 WHERE p2.category_id = p.category_id) as avg_category_price
FROM products p
WHERE p.status = 1
ORDER BY order_count DESC;

-- 3. 聚合查询性能测试
EXPLAIN SELECT 
    c1.name as main_category,
    COUNT(p.id) as product_count,
    AVG(p.price) as avg_price,
    SUM(p.sales_count) as total_sales,
    MAX(p.view_count) as max_views
FROM categories c1
LEFT JOIN categories c2 ON c1.id = c2.parent_id
LEFT JOIN products p ON c2.id = p.category_id
WHERE c1.parent_id = 0
GROUP BY c1.id, c1.name
ORDER BY product_count DESC;
```

### 8.6 基础数据使用指南

#### 8.6.1 学习路径建议
1. **第一阶段：基础操作**
   - 执行8.1.1的完整初始化脚本
   - 练习示例1-6的基础查询
   - 熟悉表结构和数据关系

2. **第二阶段：进阶查询**
   - 练习示例7-9的聚合查询
   - 掌握示例10-12的连接查询
   - 理解示例13-15的子查询

3. **第三阶段：数据操作**
   - 练习示例16-21的更新操作
   - 掌握示例22-26的删除操作
   - 学习事务和安全操作

4. **第四阶段：综合应用**
   - 执行数据验证查询
   - 分析性能测试结果
   - 设计自己的查询场景

#### 8.6.2 注意事项
1. **数据一致性**：所有示例都基于8.1.1的基础数据，确保先执行初始化脚本
2. **ID固定性**：使用指定ID插入，确保示例中的ID引用正确
3. **预期结果**：每个示例都提供了预期结果，便于验证执行正确性
4. **安全操作**：更新和删除示例都包含验证步骤，避免误操作

#### 8.6.3 扩展练习建议
1. **修改示例参数**：调整查询条件，观察结果变化
2. **组合查询**：将多个示例组合成更复杂的查询
3. **添加新数据**：在基础数据基础上插入新记录，测试查询效果
4. **性能优化**：使用EXPLAIN分析查询性能，尝试优化慢查询

## 9. 实用技巧

### 9.1 数据备份
```sql
-- 导出数据
mysqldump -u username -p database_name > backup.sql

-- 导入数据
mysql -u username -p database_name < backup.sql
```

### 9.2 性能优化
```sql
-- 查看查询执行计划
EXPLAIN SELECT * FROM users WHERE username = 'john_doe';

-- 分析表
ANALYZE TABLE table_name;

-- 优化表
OPTIMIZE TABLE table_name;
```

### 9.3 安全建议
1. 始终使用参数化查询防止SQL注入
2. 定期备份重要数据
3. 使用强密码和适当的权限设置
4. 避免在生产环境直接执行DDL语句
5. 重要操作前先测试

## 10. 常见错误和解决方案

### 10.1 连接错误
```sql
-- 错误：Access denied for user
-- 解决：检查用户名和密码是否正确

-- 错误：Can't connect to MySQL server
-- 解决：检查MySQL服务是否启动，端口是否正确
```

### 10.2 语法错误
```sql
-- 错误：You have an error in your SQL syntax
-- 解决：检查SQL语句语法，特别注意引号、括号匹配

-- 错误：Unknown column
-- 解决：检查表名和列名是否正确
```

### 10.3 数据错误
```sql
-- 错误：Duplicate entry for key
-- 解决：检查唯一约束，避免重复数据

-- 错误：Cannot add or update a child row
-- 解决：检查外键约束，确保引用数据存在
```

---

## 总结

本教程涵盖了MySQL的基础操作，包括：
- 数据库和表的基本操作
- 数据的增删改查（CRUD）
- 高级查询技巧
- 常用函数
- 实际业务场景示例
- 实用技巧和最佳实践

建议在实际使用中：
1. 先在测试环境练习
2. 重要操作前备份数据
3. 遵循数据库设计规范
4. 注意SQL注入安全
5. 定期维护和优化数据库 