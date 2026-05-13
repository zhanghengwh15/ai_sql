## ADDED Requirements

### Requirement: 完整 MVP 数据库表结构
系统 SHALL 定义电商微信小程序 MVP 及运营管理端的完整 MySQL 8 数据库表结构，覆盖用户、地址、商品、SKU、购物车、订单、支付、退款、库存、营销、售后、发货、图片管理、运营管理、幂等记录和领域事件数据。

#### Scenario: 表结构覆盖所有核心领域
- **WHEN** 评审数据库表结构是否可进入实施
- **THEN** 表结构包含用户、用户地址、分类、品牌、商品、商品 SKU、购物车、订单、订单明细、订单日志、支付记录、退款记录、库存、库存流水、优惠券、用户优惠券、秒杀活动、售后单、发货、图片资产、运营管理、领域事件和幂等记录相关表

### Requirement: 包含运营管理端表结构
系统 SHALL 包含标准运营管理端表，用于后台账号安全、RBAC 授权、控制台菜单、审计追踪、平台配置、首页运营、图片资产管理、文件素材管理和配送配置。

#### Scenario: 运营管理端表被评审
- **WHEN** 评审运营管理端表结构
- **THEN** 表结构包含 `admin_users`、`admin_roles`、`admin_permissions`、`admin_user_roles`、`admin_role_permissions`、`admin_menus`、`admin_login_logs`、`admin_operation_logs`、`system_configs`、`image_assets`、`operation_banners`、`operation_nav_items`、`file_assets`、`logistics_companies`、`freight_templates` 和 `freight_template_rules`

### Requirement: 集中管理 OSS 图片资产
系统 SHALL 定义 `image_assets` 表保存基于 OSS 的图片元数据，包括 bucket、object key、访问 URL 或 CDN URL、原始文件名、内容类型、文件大小、宽度、高度、checksum、用途类型、上传人、状态和可选元数据。

#### Scenario: 运营人员上传图片
- **WHEN** 运营人员为商品、分类、品牌、首页轮播图、导航入口、营销活动、售后凭证或富文本内容上传图片
- **THEN** 系统将二进制对象存入 OSS，并创建或更新包含可查询元数据和状态的 `image_assets` 记录

### Requirement: 小程序轮播图使用受管图片资产
系统 SHALL 定义小程序轮播图记录，并引用受管图片资产，而不是只保存原始图片 URL。

#### Scenario: 配置小程序首页轮播图
- **WHEN** 运营人员配置首页轮播图
- **THEN** `operation_banners` 记录引用 `image_assets.id`，并保存跳转类型、跳转目标、展示时间窗口、排序和状态

### Requirement: 运营管理端访问基于角色授权
系统 SHALL 通过后台用户、角色、权限以及角色菜单或角色权限关系建模后台访问控制，而不是在代码中硬编码授权。

#### Scenario: 管理员登录运营控制台
- **WHEN** 管理员登录并打开运营控制台
- **THEN** 系统可以从保留的 RBAC 表中推导该用户可访问的菜单和权限

### Requirement: 表结构不包含组织租户字段
系统 SHALL NOT 在任何表或索引中包含 `org_id` 字段。

#### Scenario: 检查表定义
- **WHEN** 检查任意表 DDL 或模型定义
- **THEN** 表中不存在 `org_id` 字段，索引中也不引用 `org_id`

### Requirement: 所有表保留记录
系统 SHALL 保留所有表的记录，并使用明确状态字段表达禁用、下架、取消、关闭、过期、失败、退款、归档或其他非活跃业务状态。

#### Scenario: 业务记录进入非活跃状态
- **WHEN** 用户、商品、优惠券、订单、支付、库存记录、售后单、后台账号、运营配置、幂等记录或领域事件进入非活跃或终态
- **THEN** 系统更新状态字段，而不是物理删除行或设置 `deleted_at`

### Requirement: 基础字段保持一致
系统 SHALL 为每张业务表定义一致的基础字段：`id`、`created_at`、`updated_at` 和 `deleted_at`，其中 `deleted_at` 仅保留用于技术兼容，不作为正常业务生命周期字段。

#### Scenario: 新增业务表
- **WHEN** 小程序数据库结构新增业务表
- **THEN** 该表包含带注释和合理默认值的 `id`、`created_at`、`updated_at` 和 `deleted_at` 字段

### Requirement: 不声明数据库外键
系统 SHALL 文档化表关系并为关联字段建立索引，但 SHALL NOT 声明数据库级外键约束。

#### Scenario: 定义关联字段
- **WHEN** 表通过 `user_id`、`product_id`、`sku_id`、`order_id`、`coupon_id` 或 `order_no` 等字段引用其他表
- **THEN** 关联字段被文档化，并在属于查询路径时建立索引，但不创建数据库外键约束

### Requirement: 为业务唯一性建立索引
系统 SHALL 为需要唯一的稳定业务标识定义唯一索引。

#### Scenario: 创建或查询业务键
- **WHEN** 通过 `openid`、`spu_code`、`sku_code`、`order_no`、`after_sale_no` 或 `idempotency_key` 等键创建或查询记录
- **THEN** 表结构提供可强制唯一性并支持直接查询的唯一索引

### Requirement: 为用户侧高频查询路径建立索引
系统 SHALL 为用户侧高频查询路径定义复合索引。

#### Scenario: 用户打开常见小程序页面
- **WHEN** 用户打开购物车、地址、优惠券、商品列表、商品详情、订单列表、订单详情或售后列表页面
- **THEN** 表结构提供匹配用户、状态、商品、SKU、分类和时间过滤条件的索引

### Requirement: 为 worker 和运营后台扫描建立索引
系统 SHALL 为后台 worker 和运营管理端查询路径定义复合索引，包括超时关单、支付回调查询、事件重试、库存对账、后台登录日志、后台操作日志、菜单树加载和基于状态的后台列表。

#### Scenario: 后台 worker 扫描待处理任务
- **WHEN** worker 扫描待处理订单、失败领域事件、支付记录或库存流水
- **THEN** 表结构根据扫描需要提供状态、重试时间、引用单号、SKU、订单号或创建时间索引

#### Scenario: 运营人员查看后台记录
- **WHEN** 运营人员筛选后台用户、角色、权限、菜单、登录日志、操作日志、图片资产、轮播图、导航入口、物流公司或运费模板
- **THEN** 表结构提供匹配账号、角色、权限、模块、用途类型、状态、排序和时间条件的索引

### Requirement: 订单和支付结构支持幂等
系统 SHALL 为订单创建、支付回调处理、退款处理和异步事件发布提供幂等数据结构支持。

#### Scenario: 收到重复请求或回调
- **WHEN** 系统收到重复下单请求、微信支付回调、退款回调或领域事件重试
- **THEN** 系统可以通过唯一或已索引业务键识别既有处理结果，避免产生重复业务影响

### Requirement: 保留历史快照
系统 SHALL 在源记录后续可能变化的场景下保留不可变历史快照。

#### Scenario: 查看历史订单或售后记录
- **WHEN** 商品、地址、优惠券或用户数据变化后查看订单、订单明细、支付回调、购物车项或售后单
- **THEN** 记录仍保留审计、客服和对账所需的相关 JSON 快照

### Requirement: 金额字段精度统一
系统 SHALL 将金额、价格、折扣、运费、退款、优惠门槛、优惠金额和秒杀价等金额类字段统一定义为 `DECIMAL(19,7)`。

#### Scenario: 定义金额类字段
- **WHEN** 表结构新增或修改金额、价格、折扣、运费、退款、优惠门槛、优惠金额或秒杀价字段
- **THEN** 字段类型使用 `DECIMAL(19,7)`，并保留字段注释说明业务含义
