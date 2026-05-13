# 小程序 MVP 数据库设计文档

## 1. 概述

本文档为 `design-miniapp-database-schema` change 的实施产物，定义微信小程序电商 MVP 与运营管理端所需的 MySQL 8 数据库结构、状态模型、索引策略与服务层约束。

设计基线：

- 仅单业务平台，不引入 `org_id`，我们不是 saas 系统，不用引入商户的概念。
- 不声明数据库外键约束，关联完整性由应用服务层维护。
- 所有业务表统一基础字段：`id`、`created_at`、`updated_at`。
- 不允许物理删除，通过业务状态字段表达生命周期。
- 金额类字段统一使用 `DECIMAL(19,7)`。
- 商品图集使用独立关系表，不在商品表存 JSON 图集数组。
- 完整 DDL 见 `doc/miniapp_mvp_schema.sql`。

## 2. 领域表清单

### 2.1 用户与地址

- `users`：用户主档（openid、昵称、状态、最近登录信息）。
- `user_addresses`：用户收货地址（默认地址标记、区域信息、地址状态）。

### 2.2 商品与目录

- `categories`：商品分类（树结构、排序、启停状态）。
- `brands`：品牌信息（名称、logo、启停状态）。
- `products`：SPU 主档（编码、标题、主图、上下架、审核状态）。
- `product_skus`：SKU 信息（编码、规格快照、价格、库存状态）。
- `product_image_relations`：商品图集关系（`product_id` + `image_asset_id` + `sort_order`）。

### 2.3 交易与履约

- `cart_items`：购物车条目（用户、SKU、数量、快照）。
- `orders`：订单主档（订单号、金额汇总、收货快照、支付状态、履约状态）。
- `order_items`：订单明细（SKU 快照、成交单价、优惠分摊）。
- `order_logs`：订单状态流转日志。
- `payment_records`：支付记录（微信支付单号、回调状态、幂等键）。
- `refund_records`：退款记录（退款单号、退款状态、回调状态）。
- `after_sale_orders`：售后单（退货/退款类型、状态、协商记录）。
- `shipments`：发货单（快递公司、运单号、电子面单、揽收状态、取消面单状态）。
- `shipment_tracks`：物流轨迹明细（轨迹时间、轨迹节点、原始响应）。
- `shipment_notify_logs`：物流通知日志（订阅消息模板、发送状态、重试信息）。

### 2.4 库存与营销

- `inventories`：库存主表（可售库存、锁定库存、版本号）。
- `inventory_logs`：库存流水（入库/锁定/扣减/回滚）。
- `coupons`：优惠券定义（门槛、优惠金额、有效期、发放规则）。
- `user_coupons`：用户券实例（领取、使用、过期状态）。
- `seckill_activities`：秒杀活动（活动时间窗、限购、秒杀价）。

### 2.5 运营后台与资源管理

- `admin_users`、`admin_roles`、`admin_permissions`、`admin_user_roles`、`admin_role_permissions`。
- `admin_menus`、`admin_login_logs`、`admin_operation_logs`。
- `system_configs`。
- `image_assets`、`file_assets`。
- `operation_banners`、`operation_nav_items`。
- `logistics_companies`、`freight_templates`、`freight_template_rules`。

说明：MVP 暂不引入部门/岗位表。

### 2.6 系统支撑

- `domain_events`：领域事件 outbox。
- `idempotency_records`：幂等记录表。

## 3. 关键关系说明（应用层维护）

- `user_addresses.user_id -> users.id`
- `products.category_id -> categories.id`
- `products.brand_id -> brands.id`
- `product_skus.product_id -> products.id`
- `product_image_relations.product_id -> products.id`
- `product_image_relations.image_asset_id -> image_assets.id`
- `cart_items.user_id -> users.id`
- `cart_items.sku_id -> product_skus.id`
- `orders.user_id -> users.id`
- `order_items.order_id -> orders.id`
- `order_items.sku_id -> product_skus.id`
- `payment_records.order_id -> orders.id`
- `refund_records.order_id -> orders.id`
- `after_sale_orders.order_id -> orders.id`
- `shipments.order_id -> orders.id`
- `shipment_tracks.shipment_id -> shipments.id`
- `shipment_notify_logs.shipment_id -> shipments.id`
- `inventories.sku_id -> product_skus.id`
- `inventory_logs.inventory_id -> inventories.id`
- `user_coupons.coupon_id -> coupons.id`
- `user_coupons.user_id -> users.id`

## 4. 状态模型与生命周期

统一原则：状态字段显式表达生命周期，不删除记录。

- 用户：`status`（正常/禁用/注销占位）。
- 商品：`publish_status`（草稿/上架/下架）+ `audit_status`（待审/通过/拒绝）。
- 订单：`order_status`（待支付/待发货/待收货/已完成/已取消）。
- 支付：`pay_status`（待支付/成功/失败/关闭）。
- 退款：`refund_status`（申请中/处理中/成功/失败/关闭）。
- 发货：`shipment_status`（待建单/已建单/已发货/已签收/已取消）。
- 物流：`pickup_status`（未揽收/已揽收），`cancel_status`（未取消/取消中/取消成功/取消失败）。
- 优惠券：`coupon_status`、`user_coupon_status`。
- 领域事件：`event_status`（待发布/处理中/成功/失败/终止）。

## 5. 微信物流数据落点与取舍

选型：采用 `shipments + shipment_tracks + shipment_notify_logs` 三表。

- `shipments` 保存当前最新物流态与运单主信息，适合订单详情读取。
- `shipment_tracks` 保存轨迹历史明细，支持时间线回放和审计。
- `shipment_notify_logs` 保存订阅消息发送尝试与结果，支持重试与追踪。

拒绝方案：仅扩展 `shipments` 单表保存所有轨迹 JSON。原因是轨迹查询、审计与重试日志会变得难维护且难索引。

## 6. 索引设计要点

### 6.1 业务唯一索引

- `users.uk_users_openid`
- `products.uk_products_spu_code`
- `product_skus.uk_product_skus_sku_code`
- `orders.uk_orders_order_no`
- `after_sale_orders.uk_after_sale_orders_after_sale_no`
- `idempotency_records.uk_idempotency_records_idempotency_key`

### 6.2 小程序高频查询索引

- 购物车：`cart_items.idx_cart_items_user_status_updated`
- 地址：`user_addresses.idx_user_addresses_user_default_status`
- 订单列表：`orders.idx_orders_user_status_created`
- 售后列表：`after_sale_orders.idx_after_sale_orders_user_status_created`
- 优惠券列表：`user_coupons.idx_user_coupons_user_status_expire`

### 6.3 Worker 与运营端索引

- 超时关单：`orders.idx_orders_status_expire_at`
- 支付回调：`payment_records.idx_payment_records_pay_status_paid_at`
- 事件重试：`domain_events.idx_domain_events_status_next_retry`
- 库存对账：`inventory_logs.idx_inventory_logs_type_created`
- 后台日志：`admin_login_logs.idx_admin_login_logs_user_created`、`admin_operation_logs.idx_admin_operation_logs_module_created`

### 6.4 微信物流索引

- 物流单查询：`shipments.uk_shipments_waybill_no`、`shipments.idx_shipments_order_id`
- 轨迹任务扫描：`shipments.idx_shipments_status_track_pull`
- 轨迹明细：`shipment_tracks.idx_shipment_tracks_shipment_track_time`
- 通知补偿：`shipment_notify_logs.idx_shipment_notify_logs_status_next_retry`

## 7. Repository 查询约定

- 列表查询统一走“过滤列 + 时间列”复合索引。
- 用户侧分页优先使用 `created_at` 游标分页，避免大偏移 `offset`。
- Worker 扫描使用状态 + 下一次重试时间窗口索引。
- 订单、支付、退款、物流接口优先按业务单号查询，避免非索引条件扫描。

## 8. 服务层约束

- 禁止调用物理删除 SQL；状态流转必须通过服务方法封装。
- 支付成功前禁止调用 `logistics.addOrder` 建单。
- 仅在未揽收状态允许调用 `logistics.cancelOrder`。
- 订阅消息发送失败写入 `shipment_notify_logs` 并按重试策略补偿。
- 幂等处理统一落 `idempotency_records`，关键写操作要求携带幂等键。

## 9. 归档策略（后续）

- 订单、日志、轨迹、操作审计等大表按时间分段归档到冷表。
- 归档仅搬迁历史副本，不删除主表原始业务记录（可通过状态与归档标识区分）。
- 归档任务与在线写入解耦，采用离峰批处理。
