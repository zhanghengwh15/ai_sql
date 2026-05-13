## 1. 数据库设计文档

- [x] 1.1 创建完整的小程序端和运营管理端数据库设计文档，包含表用途、表关系、状态枚举和生命周期规则
- [x] 1.2 定义每张表的通用基础字段（`id`、`created_at`、`updated_at`），并说明所有表保留记录，不执行物理删除或逻辑删除
- [x] 1.3 确认所有表和索引均不包含 `org_id`
- [x] 1.4 说明关联字段需要建立索引，但不声明数据库外键约束
- [x] 1.5 说明金额、价格、折扣、运费、退款、优惠门槛、优惠金额和秒杀价等字段统一使用 `DECIMAL(19,7)`

## 2. 表结构定义

- [x] 2.1 定义用户和地址表：`users`、`user_addresses`
- [x] 2.2 定义商品目录表：`categories`、`brands`、`products`、`product_skus`
- [x] 2.3 定义购物车表：`cart_items`
- [x] 2.4 定义订单表：`orders`、`order_items`、`order_logs`
- [x] 2.5 定义支付和退款表：`payment_records`、`refund_records`
- [x] 2.6 定义库存表：`inventories`、`inventory_logs`
- [x] 2.7 定义营销表：`coupons`、`user_coupons`、`seckill_activities`
- [x] 2.8 定义售后和发货表：`after_sale_orders`、`shipments`
- [x] 2.9 定义运营账号和 RBAC 表：`admin_users`、`admin_roles`、`admin_permissions`、`admin_user_roles`、`admin_role_permissions`
- [x] 2.10 定义运营控制台表：`admin_menus`、`admin_login_logs`、`admin_operation_logs`
- [x] 2.11 定义基于 OSS 的图片管理表：`image_assets`
- [x] 2.11.1 定义商品图集关系表（如 `product_image_relations`），维护商品与图片资产的有序关联
- [x] 2.12 定义运营配置和内容表：`system_configs`、`operation_banners`、`operation_nav_items`、`file_assets`
- [x] 2.13 确保 `operation_banners` 通过 `image_assets` 引用小程序轮播图图片
- [x] 2.14 定义物流和运费表：`logistics_companies`、`freight_templates`、`freight_template_rules`
- [x] 2.15 定义支撑表：`domain_events`、`idempotency_records`
- [x] 2.16 在发货域补充微信物流履约字段与状态：快递公司编码、运单号、电子面单号、揽收状态、物流轨迹拉取时间、取消面单状态
- [x] 2.17 明确物流轨迹与通知数据落点（可复用 `shipments` 扩展字段，或新增物流轨迹/通知日志表）并记录取舍

## 3. 索引设计

- [x] 3.1 为 `openid`、`spu_code`、`sku_code`、`order_no`、`after_sale_no` 和 `idempotency_key` 等业务键增加唯一索引
- [x] 3.2 为购物车、地址、优惠券、商品列表、订单列表和售后列表查询增加小程序端复合索引
- [x] 3.3 为超时关单扫描、支付回调查询、领域事件重试、库存对账、后台登录日志、后台操作日志、菜单树、图片资产用途/状态扫描和状态列表增加 worker 与运营后台索引
- [x] 3.4 检查索引命名是否符合项目 database-design 规范
- [x] 3.5 为微信物流查询路径增加索引：按订单号/运单号查询物流单、按物流状态和更新时间扫描轨迹拉取任务

## 4. SQL / 迁移准备

- [x] 4.1 将确认后的表设计转换为可执行的 MySQL 8 DDL 或迁移脚本，并沉淀到 `doc/` 目录
- [x] 4.2 统一补充字段注释、默认值、`NOT NULL` 约束、JSON 字段和 `DECIMAL(19,7)` 金额字段类型
- [ ] 4.3 在本地 MySQL 8 实例验证 DDL
- [ ] 4.4 使用 `SHOW INDEX` 或等价方式检查生成的索引

## 5. 应用层约束

- [x] 5.1 增加或文档化服务层保护，禁止所有表执行物理删除和软删除
- [x] 5.2 确保模型和服务通过状态字段表达非活跃业务状态
- [x] 5.3 确保 Repository 查询使用已设计的常见列表和 worker 路径复合索引
- [x] 5.4 补充未来归档表的实施说明，并强调原始记录仍需保留
- [x] 5.5 增加微信物流服务层约束：支付成功后才允许建单，未揽收才允许取消面单，订阅消息发送失败可重试且可审计
