-- 小程序 MVP 数据库 DDL（MySQL 8）
-- Change: design-miniapp-database-schema
-- 约束：
-- 1) 不含 org_id
-- 2) 不使用外键约束
-- 3) 基础字段统一：id, created_at, updated_at
-- 4) 金额字段统一 DECIMAL(19,7)

SET NAMES utf8mb4;

CREATE TABLE `users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `openid` VARCHAR(64) NOT NULL COMMENT '微信openid',
  `nickname` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '昵称',
  `avatar_url` VARCHAR(512) NOT NULL DEFAULT '' COMMENT '头像',
  `mobile` VARCHAR(20) NOT NULL DEFAULT '' COMMENT '手机号',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1正常,2禁用',
  `last_login_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '最近登录时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_users_openid` (`openid`),
  KEY `idx_users_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户表';

CREATE TABLE `user_addresses` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `receiver_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '收件人',
  `receiver_phone` VARCHAR(20) NOT NULL DEFAULT '' COMMENT '联系电话',
  `province_code` VARCHAR(16) NOT NULL DEFAULT '' COMMENT '省编码',
  `city_code` VARCHAR(16) NOT NULL DEFAULT '' COMMENT '市编码',
  `district_code` VARCHAR(16) NOT NULL DEFAULT '' COMMENT '区编码',
  `address_detail` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '详细地址',
  `is_default` TINYINT NOT NULL DEFAULT 0 COMMENT '是否默认:0否,1是',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1有效,2停用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_addresses_user_default_status` (`user_id`, `is_default`, `status`),
  KEY `idx_user_addresses_user_created` (`user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户地址表';

CREATE TABLE `categories` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `parent_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '父分类ID',
  `name` VARCHAR(64) NOT NULL COMMENT '分类名',
  `icon_image_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '图标资产ID',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1启用,2禁用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_categories_parent_status_sort` (`parent_id`, `status`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='分类表';

CREATE TABLE `brands` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` VARCHAR(128) NOT NULL COMMENT '品牌名',
  `logo_image_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'logo资产ID',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1启用,2禁用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_brands_name` (`name`),
  KEY `idx_brands_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='品牌表';

CREATE TABLE `products` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `spu_code` VARCHAR(64) NOT NULL COMMENT 'SPU编码',
  `category_id` BIGINT UNSIGNED NOT NULL COMMENT '分类ID',
  `brand_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '品牌ID',
  `name` VARCHAR(255) NOT NULL COMMENT '商品名',
  `sub_title` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '副标题',
  `main_image_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '主图资产ID',
  `publish_status` TINYINT NOT NULL DEFAULT 1 COMMENT '上架状态:1草稿,2上架,3下架',
  `audit_status` TINYINT NOT NULL DEFAULT 1 COMMENT '审核状态:1待审,2通过,3拒绝',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_products_spu_code` (`spu_code`),
  KEY `idx_products_category_status_created` (`category_id`, `publish_status`, `created_at`),
  KEY `idx_products_brand_status_created` (`brand_id`, `publish_status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品SPU表';

CREATE TABLE `product_skus` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  `sku_code` VARCHAR(64) NOT NULL COMMENT 'SKU编码',
  `spec_snapshot` JSON NOT NULL COMMENT '规格快照',
  `sale_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '销售价',
  `market_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '市场价',
  `cost_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '成本价',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1启用,2停用',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_skus_sku_code` (`sku_code`),
  KEY `idx_product_skus_product_status_created` (`product_id`, `status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品SKU表';

CREATE TABLE `product_image_relations` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  `image_asset_id` BIGINT UNSIGNED NOT NULL COMMENT '图片资产ID',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1有效,2无效',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_product_image_relations_product_image` (`product_id`, `image_asset_id`),
  KEY `idx_product_image_relations_product_sort` (`product_id`, `status`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='商品图集关系表';

CREATE TABLE `cart_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `sku_id` BIGINT UNSIGNED NOT NULL COMMENT 'SKU ID',
  `quantity` INT NOT NULL DEFAULT 1 COMMENT '数量',
  `checked` TINYINT NOT NULL DEFAULT 1 COMMENT '选中状态:0否,1是',
  `price_snapshot` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '价格快照',
  `sku_snapshot` JSON NOT NULL COMMENT 'SKU快照',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1有效,2失效',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_cart_items_user_sku` (`user_id`, `sku_id`),
  KEY `idx_cart_items_user_status_updated` (`user_id`, `status`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='购物车表';

CREATE TABLE `orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `order_status` TINYINT NOT NULL DEFAULT 1 COMMENT '订单状态:1待支付,2待发货,3待收货,4已完成,5已取消',
  `pay_status` TINYINT NOT NULL DEFAULT 1 COMMENT '支付状态:1待支付,2已支付,3已关闭',
  `shipment_status` TINYINT NOT NULL DEFAULT 1 COMMENT '履约状态:1待发货,2已发货,3已签收,4取消',
  `items_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '商品总额',
  `discount_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '优惠金额',
  `freight_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '运费',
  `payable_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '应付金额',
  `paid_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '实付金额',
  `address_snapshot` JSON NOT NULL COMMENT '地址快照',
  `remark` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '用户备注',
  `expire_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '支付过期时间',
  `paid_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '支付时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_orders_order_no` (`order_no`),
  KEY `idx_orders_user_status_created` (`user_id`, `order_status`, `created_at`),
  KEY `idx_orders_status_expire_at` (`order_status`, `expire_at`),
  KEY `idx_orders_pay_status_paid_at` (`pay_status`, `paid_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单表';

CREATE TABLE `order_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  `sku_id` BIGINT UNSIGNED NOT NULL COMMENT 'SKU ID',
  `sku_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'SKU名快照',
  `sku_spec_snapshot` JSON NOT NULL COMMENT '规格快照',
  `quantity` INT NOT NULL DEFAULT 1 COMMENT '数量',
  `unit_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '单价',
  `discount_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '优惠分摊',
  `pay_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '实付小计',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_order_items_order_id` (`order_id`),
  KEY `idx_order_items_order_no` (`order_no`),
  KEY `idx_order_items_sku_id` (`sku_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单明细表';

CREATE TABLE `order_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `action_type` VARCHAR(32) NOT NULL COMMENT '动作类型',
  `before_status` TINYINT NOT NULL DEFAULT 0 COMMENT '变更前状态',
  `after_status` TINYINT NOT NULL DEFAULT 0 COMMENT '变更后状态',
  `operator_type` TINYINT NOT NULL DEFAULT 1 COMMENT '操作人类型:1用户,2后台,3系统',
  `operator_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '操作人ID',
  `remark` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '备注',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_order_logs_order_created` (`order_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='订单日志表';

CREATE TABLE `payment_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `pay_no` VARCHAR(64) NOT NULL COMMENT '支付流水号',
  `channel` VARCHAR(32) NOT NULL DEFAULT 'wechat' COMMENT '支付渠道',
  `transaction_id` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '微信支付交易号',
  `pay_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '支付金额',
  `pay_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1待支付,2成功,3失败,4关闭',
  `idempotency_key` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '回调幂等键',
  `paid_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '支付成功时间',
  `callback_payload` JSON NOT NULL COMMENT '回调报文',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_payment_records_pay_no` (`pay_no`),
  KEY `idx_payment_records_order_id` (`order_id`),
  KEY `idx_payment_records_pay_status_paid_at` (`pay_status`, `paid_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='支付记录表';

CREATE TABLE `refund_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `refund_no` VARCHAR(64) NOT NULL COMMENT '退款单号',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `payment_record_id` BIGINT UNSIGNED NOT NULL COMMENT '支付记录ID',
  `refund_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '退款金额',
  `refund_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1申请中,2处理中,3成功,4失败,5关闭',
  `reason` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '退款原因',
  `callback_payload` JSON NOT NULL COMMENT '退款回调',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_refund_records_refund_no` (`refund_no`),
  KEY `idx_refund_records_order_id` (`order_id`),
  KEY `idx_refund_records_status_created` (`refund_status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='退款记录表';

CREATE TABLE `inventories` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `sku_id` BIGINT UNSIGNED NOT NULL COMMENT 'SKU ID',
  `total_stock` INT NOT NULL DEFAULT 0 COMMENT '总库存',
  `available_stock` INT NOT NULL DEFAULT 0 COMMENT '可售库存',
  `locked_stock` INT NOT NULL DEFAULT 0 COMMENT '锁定库存',
  `version` INT NOT NULL DEFAULT 1 COMMENT '版本号',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1正常,2冻结',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_inventories_sku_id` (`sku_id`),
  KEY `idx_inventories_status_updated` (`status`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存表';

CREATE TABLE `inventory_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `inventory_id` BIGINT UNSIGNED NOT NULL COMMENT '库存ID',
  `sku_id` BIGINT UNSIGNED NOT NULL COMMENT 'SKU ID',
  `order_no` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '订单号',
  `change_type` TINYINT NOT NULL COMMENT '类型:1入库,2锁定,3扣减,4回滚',
  `change_qty` INT NOT NULL DEFAULT 0 COMMENT '变更数量',
  `before_available` INT NOT NULL DEFAULT 0 COMMENT '变更前可售',
  `after_available` INT NOT NULL DEFAULT 0 COMMENT '变更后可售',
  `remark` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '备注',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_inventory_logs_type_created` (`change_type`, `created_at`),
  KEY `idx_inventory_logs_sku_created` (`sku_id`, `created_at`),
  KEY `idx_inventory_logs_order_no` (`order_no`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='库存流水表';

CREATE TABLE `coupons` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `coupon_code` VARCHAR(64) NOT NULL COMMENT '券编码',
  `name` VARCHAR(128) NOT NULL COMMENT '券名称',
  `coupon_type` TINYINT NOT NULL DEFAULT 1 COMMENT '类型:1满减,2折扣',
  `threshold_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '门槛金额',
  `discount_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '优惠金额',
  `discount_rate` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '折扣率',
  `total_count` INT NOT NULL DEFAULT 0 COMMENT '总发放',
  `issued_count` INT NOT NULL DEFAULT 0 COMMENT '已发放',
  `used_count` INT NOT NULL DEFAULT 0 COMMENT '已使用',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1生效,2停用,3过期',
  `valid_start_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '有效期开始',
  `valid_end_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '有效期结束',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_coupons_coupon_code` (`coupon_code`),
  KEY `idx_coupons_status_valid_end` (`status`, `valid_end_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='优惠券定义表';

CREATE TABLE `user_coupons` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `coupon_id` BIGINT UNSIGNED NOT NULL COMMENT '券ID',
  `coupon_code` VARCHAR(64) NOT NULL COMMENT '券编码',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1未使用,2已使用,3已过期',
  `received_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '领取时间',
  `used_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '使用时间',
  `expire_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '过期时间',
  `order_no` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '使用订单号',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_coupons_user_status_expire` (`user_id`, `status`, `expire_at`),
  KEY `idx_user_coupons_coupon_status` (`coupon_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='用户优惠券表';

CREATE TABLE `seckill_activities` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `activity_code` VARCHAR(64) NOT NULL COMMENT '活动编码',
  `product_id` BIGINT UNSIGNED NOT NULL COMMENT '商品ID',
  `sku_id` BIGINT UNSIGNED NOT NULL COMMENT 'SKU ID',
  `seckill_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '秒杀价',
  `stock_limit` INT NOT NULL DEFAULT 0 COMMENT '活动库存',
  `per_user_limit` INT NOT NULL DEFAULT 1 COMMENT '每人限购',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1待开始,2进行中,3已结束,4停用',
  `start_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '开始时间',
  `end_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '结束时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_seckill_activities_activity_code` (`activity_code`),
  KEY `idx_seckill_activities_status_time` (`status`, `start_at`, `end_at`),
  KEY `idx_seckill_activities_sku_status` (`sku_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='秒杀活动表';

CREATE TABLE `after_sale_orders` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `after_sale_no` VARCHAR(64) NOT NULL COMMENT '售后单号',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `order_item_id` BIGINT UNSIGNED NOT NULL COMMENT '订单明细ID',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `after_sale_type` TINYINT NOT NULL DEFAULT 1 COMMENT '类型:1仅退款,2退货退款',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1申请中,2处理中,3完成,4拒绝,5关闭',
  `apply_reason` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '申请原因',
  `apply_snapshot` JSON NOT NULL COMMENT '申请快照',
  `refund_amount` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '退款金额',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_after_sale_orders_after_sale_no` (`after_sale_no`),
  KEY `idx_after_sale_orders_user_status_created` (`user_id`, `status`, `created_at`),
  KEY `idx_after_sale_orders_order_id` (`order_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='售后单表';

CREATE TABLE `shipments` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `order_id` BIGINT UNSIGNED NOT NULL COMMENT '订单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `shipment_no` VARCHAR(64) NOT NULL COMMENT '发货单号',
  `carrier_code` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '快递公司编码',
  `carrier_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '快递公司名称',
  `waybill_no` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '运单号',
  `express_sheet_no` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '电子面单号',
  `shipment_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1待建单,2已建单,3已发货,4已签收,5已取消',
  `pickup_status` TINYINT NOT NULL DEFAULT 1 COMMENT '揽收状态:1未揽收,2已揽收',
  `cancel_status` TINYINT NOT NULL DEFAULT 1 COMMENT '取消面单状态:1未取消,2取消中,3成功,4失败',
  `track_pull_status` TINYINT NOT NULL DEFAULT 1 COMMENT '轨迹拉取状态:1待拉取,2拉取中,3成功,4失败',
  `last_track_pull_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '最近拉取时间',
  `next_track_pull_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '下次拉取时间',
  `delivered_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '签收时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_shipments_shipment_no` (`shipment_no`),
  UNIQUE KEY `uk_shipments_waybill_no` (`waybill_no`),
  KEY `idx_shipments_order_id` (`order_id`),
  KEY `idx_shipments_status_track_pull` (`track_pull_status`, `next_track_pull_at`),
  KEY `idx_shipments_shipment_status_updated` (`shipment_status`, `updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='发货单表';

CREATE TABLE `shipment_tracks` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `shipment_id` BIGINT UNSIGNED NOT NULL COMMENT '发货单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `waybill_no` VARCHAR(64) NOT NULL COMMENT '运单号',
  `track_time` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '轨迹时间',
  `track_status` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '轨迹状态',
  `track_desc` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '轨迹描述',
  `location` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '位置',
  `raw_payload` JSON NOT NULL COMMENT '原始轨迹报文',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_shipment_tracks_shipment_track_time` (`shipment_id`, `track_time`),
  KEY `idx_shipment_tracks_waybill_track_time` (`waybill_no`, `track_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物流轨迹表';

CREATE TABLE `shipment_notify_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `shipment_id` BIGINT UNSIGNED NOT NULL COMMENT '发货单ID',
  `order_no` VARCHAR(64) NOT NULL COMMENT '订单号',
  `template_id` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '订阅模板ID',
  `notify_type` TINYINT NOT NULL DEFAULT 1 COMMENT '通知类型:1已发货,2物流更新',
  `notify_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1待发送,2成功,3失败',
  `retry_count` INT NOT NULL DEFAULT 0 COMMENT '重试次数',
  `next_retry_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '下次重试时间',
  `request_payload` JSON NOT NULL COMMENT '请求报文',
  `response_payload` JSON NOT NULL COMMENT '响应报文',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_shipment_notify_logs_status_next_retry` (`notify_status`, `next_retry_at`),
  KEY `idx_shipment_notify_logs_shipment_created` (`shipment_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物流通知日志表';

CREATE TABLE `admin_users` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `username` VARCHAR(64) NOT NULL COMMENT '账号',
  `password_hash` VARCHAR(255) NOT NULL COMMENT '密码哈希',
  `real_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '姓名',
  `mobile` VARCHAR(20) NOT NULL DEFAULT '' COMMENT '手机号',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1启用,2禁用',
  `last_login_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '最近登录',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_users_username` (`username`),
  KEY `idx_admin_users_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台用户表';

CREATE TABLE `admin_roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `role_code` VARCHAR(64) NOT NULL COMMENT '角色编码',
  `role_name` VARCHAR(64) NOT NULL COMMENT '角色名',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_roles_role_code` (`role_code`),
  KEY `idx_admin_roles_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台角色表';

CREATE TABLE `admin_permissions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `perm_code` VARCHAR(128) NOT NULL COMMENT '权限编码',
  `perm_name` VARCHAR(128) NOT NULL COMMENT '权限名',
  `module_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '模块',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_permissions_perm_code` (`perm_code`),
  KEY `idx_admin_permissions_module_status` (`module_name`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台权限表';

CREATE TABLE `admin_user_roles` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `user_id` BIGINT UNSIGNED NOT NULL COMMENT '用户ID',
  `role_id` BIGINT UNSIGNED NOT NULL COMMENT '角色ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_user_roles_user_role` (`user_id`, `role_id`),
  KEY `idx_admin_user_roles_role_id` (`role_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台用户角色关系表';

CREATE TABLE `admin_role_permissions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `role_id` BIGINT UNSIGNED NOT NULL COMMENT '角色ID',
  `permission_id` BIGINT UNSIGNED NOT NULL COMMENT '权限ID',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_admin_role_permissions_role_perm` (`role_id`, `permission_id`),
  KEY `idx_admin_role_permissions_permission_id` (`permission_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台角色权限关系表';

CREATE TABLE `admin_menus` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `parent_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '父菜单',
  `menu_name` VARCHAR(64) NOT NULL COMMENT '菜单名',
  `menu_path` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '路径',
  `menu_icon` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '图标',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_admin_menus_parent_status_sort` (`parent_id`, `status`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台菜单表';

CREATE TABLE `admin_login_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `admin_user_id` BIGINT UNSIGNED NOT NULL COMMENT '后台用户ID',
  `username` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '账号快照',
  `login_ip` VARCHAR(45) NOT NULL DEFAULT '' COMMENT '登录IP',
  `user_agent` VARCHAR(255) NOT NULL DEFAULT '' COMMENT 'UA',
  `login_result` TINYINT NOT NULL DEFAULT 1 COMMENT '结果:1成功,2失败',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_admin_login_logs_user_created` (`admin_user_id`, `created_at`),
  KEY `idx_admin_login_logs_result_created` (`login_result`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台登录日志';

CREATE TABLE `admin_operation_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `admin_user_id` BIGINT UNSIGNED NOT NULL COMMENT '后台用户ID',
  `module_name` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '模块',
  `operation_type` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '操作类型',
  `target_id` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '目标标识',
  `request_payload` JSON NOT NULL COMMENT '请求体',
  `result_code` INT NOT NULL DEFAULT 0 COMMENT '结果码',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_admin_operation_logs_module_created` (`module_name`, `created_at`),
  KEY `idx_admin_operation_logs_user_created` (`admin_user_id`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='后台操作日志';

CREATE TABLE `system_configs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `config_key` VARCHAR(128) NOT NULL COMMENT '配置键',
  `config_value` JSON NOT NULL COMMENT '配置值',
  `description` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '描述',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_system_configs_config_key` (`config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='系统配置表';

CREATE TABLE `image_assets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `bucket_name` VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'OSS bucket',
  `object_key` VARCHAR(255) NOT NULL COMMENT '对象key',
  `origin_file_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '原文件名',
  `content_type` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '类型',
  `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '字节大小',
  `width` INT NOT NULL DEFAULT 0 COMMENT '宽',
  `height` INT NOT NULL DEFAULT 0 COMMENT '高',
  `checksum` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '校验',
  `asset_type` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '用途',
  `url` VARCHAR(512) NOT NULL DEFAULT '' COMMENT '访问URL',
  `cdn_url` VARCHAR(512) NOT NULL DEFAULT '' COMMENT 'CDN URL',
  `uploader_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '上传人',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `metadata` JSON NOT NULL COMMENT '扩展元数据',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_image_assets_object_key` (`object_key`),
  KEY `idx_image_assets_type_status_created` (`asset_type`, `status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='图片资产表';

CREATE TABLE `file_assets` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `bucket_name` VARCHAR(128) NOT NULL DEFAULT '' COMMENT 'bucket',
  `object_key` VARCHAR(255) NOT NULL COMMENT '对象key',
  `file_name` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '文件名',
  `content_type` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '类型',
  `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '大小',
  `url` VARCHAR(512) NOT NULL DEFAULT '' COMMENT 'URL',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_file_assets_object_key` (`object_key`),
  KEY `idx_file_assets_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='文件资产表';

CREATE TABLE `operation_banners` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `title` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '标题',
  `image_asset_id` BIGINT UNSIGNED NOT NULL COMMENT '图片资产ID',
  `jump_type` TINYINT NOT NULL DEFAULT 1 COMMENT '跳转类型',
  `jump_target` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '跳转目标',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `start_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '开始时间',
  `end_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '结束时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_operation_banners_status_time_sort` (`status`, `start_at`, `end_at`, `sort_order`),
  KEY `idx_operation_banners_image_id` (`image_asset_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运营轮播图表';

CREATE TABLE `operation_nav_items` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `name` VARCHAR(64) NOT NULL COMMENT '名称',
  `icon_image_id` BIGINT UNSIGNED NOT NULL DEFAULT 0 COMMENT '图标资产ID',
  `jump_type` TINYINT NOT NULL DEFAULT 1 COMMENT '跳转类型',
  `jump_target` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '跳转目标',
  `sort_order` INT NOT NULL DEFAULT 0 COMMENT '排序',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_operation_nav_items_status_sort` (`status`, `sort_order`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运营导航入口表';

CREATE TABLE `logistics_companies` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `company_code` VARCHAR(32) NOT NULL COMMENT '公司编码',
  `company_name` VARCHAR(64) NOT NULL COMMENT '公司名称',
  `service_code` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '微信服务编码',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_logistics_companies_company_code` (`company_code`),
  KEY `idx_logistics_companies_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='物流公司表';

CREATE TABLE `freight_templates` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `template_name` VARCHAR(128) NOT NULL COMMENT '模板名',
  `charge_mode` TINYINT NOT NULL DEFAULT 1 COMMENT '计费方式',
  `base_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '基础运费',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_freight_templates_status_created` (`status`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运费模板表';

CREATE TABLE `freight_template_rules` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `template_id` BIGINT UNSIGNED NOT NULL COMMENT '模板ID',
  `region_code` VARCHAR(32) NOT NULL DEFAULT '' COMMENT '区域编码',
  `first_unit` INT NOT NULL DEFAULT 1 COMMENT '首件/首重',
  `first_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '首费',
  `extra_unit` INT NOT NULL DEFAULT 1 COMMENT '续件/续重',
  `extra_price` DECIMAL(19,7) NOT NULL DEFAULT 0.0000000 COMMENT '续费',
  `status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_freight_template_rules_template_status` (`template_id`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='运费模板规则表';

CREATE TABLE `domain_events` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `event_type` VARCHAR(64) NOT NULL COMMENT '事件类型',
  `aggregate_type` VARCHAR(64) NOT NULL COMMENT '聚合类型',
  `aggregate_id` VARCHAR(64) NOT NULL COMMENT '聚合ID',
  `event_payload` JSON NOT NULL COMMENT '事件载荷',
  `event_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1待发布,2处理中,3成功,4失败,5终止',
  `retry_count` INT NOT NULL DEFAULT 0 COMMENT '重试次数',
  `next_retry_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '下次重试',
  `last_error` VARCHAR(255) NOT NULL DEFAULT '' COMMENT '最后错误',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  KEY `idx_domain_events_status_next_retry` (`event_status`, `next_retry_at`),
  KEY `idx_domain_events_aggregate` (`aggregate_type`, `aggregate_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='领域事件表';

CREATE TABLE `idempotency_records` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '主键',
  `idempotency_key` VARCHAR(128) NOT NULL COMMENT '幂等键',
  `biz_type` VARCHAR(64) NOT NULL COMMENT '业务类型',
  `biz_no` VARCHAR(64) NOT NULL DEFAULT '' COMMENT '业务单号',
  `request_hash` VARCHAR(128) NOT NULL DEFAULT '' COMMENT '请求哈希',
  `process_status` TINYINT NOT NULL DEFAULT 1 COMMENT '状态:1处理中,2成功,3失败',
  `response_payload` JSON NOT NULL COMMENT '响应快照',
  `expired_at` DATETIME NOT NULL DEFAULT '1970-01-01 08:00:00' COMMENT '过期时间',
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_idempotency_records_idempotency_key` (`idempotency_key`),
  KEY `idx_idempotency_records_biz` (`biz_type`, `biz_no`),
  KEY `idx_idempotency_records_expired_at` (`expired_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='幂等记录表';

-- =====================================================
-- 基础增删改查测试（建议在测试库执行）
-- 说明：
-- 1) 本项目约束“保留记录”，删除动作使用状态更新模拟，不执行物理 DELETE
-- 2) 以下语句用于快速验证建表后核心链路的可用性
-- =====================================================

-- 可选：切换到测试库
-- CREATE DATABASE IF NOT EXISTS miniapp_mvp_test DEFAULT CHARACTER SET utf8mb4;
-- USE miniapp_mvp_test;

-- -------- 1. 用户/地址基础测试 --------
-- C: 新增用户
INSERT INTO `users` (`openid`, `nickname`, `avatar_url`, `mobile`, `status`, `last_login_at`)
VALUES ('openid_test_001', '测试用户A', 'https://example.com/a.png', '13800000001', 1, NOW());

-- R: 查询用户
SELECT `id`, `openid`, `nickname`, `status`, `created_at`, `updated_at`
FROM `users`
WHERE `openid` = 'openid_test_001';

-- U: 更新用户昵称
UPDATE `users`
SET `nickname` = '测试用户A-改'
WHERE `openid` = 'openid_test_001';

-- D(逻辑): 禁用用户（状态流转替代物理删除）
UPDATE `users`
SET `status` = 2
WHERE `openid` = 'openid_test_001';

-- 新增地址（依赖刚创建用户）
INSERT INTO `user_addresses` (
  `user_id`, `receiver_name`, `receiver_phone`,
  `province_code`, `city_code`, `district_code`,
  `address_detail`, `is_default`, `status`
)
SELECT `id`, '张三', '13800000001', '440000', '440100', '440106', '天河路 100 号', 1, 1
FROM `users` WHERE `openid` = 'openid_test_001';

-- -------- 2. 商品/SKU/图集关系测试 --------
INSERT INTO `categories` (`parent_id`, `name`, `icon_image_id`, `sort_order`, `status`)
VALUES (0, '测试分类', 0, 1, 1);

INSERT INTO `brands` (`name`, `logo_image_id`, `status`)
VALUES ('测试品牌A', 0, 1);

INSERT INTO `products` (
  `spu_code`, `category_id`, `brand_id`, `name`, `sub_title`,
  `main_image_id`, `publish_status`, `audit_status`, `sort_order`
)
SELECT
  'SPU_TEST_001', c.`id`, b.`id`, '测试商品A', '副标题A',
  0, 2, 2, 10
FROM `categories` c, `brands` b
WHERE c.`name` = '测试分类' AND b.`name` = '测试品牌A'
LIMIT 1;

INSERT INTO `product_skus` (
  `product_id`, `sku_code`, `spec_snapshot`,
  `sale_price`, `market_price`, `cost_price`, `status`
)
SELECT
  p.`id`, 'SKU_TEST_001',
  JSON_OBJECT('color', 'black', 'size', 'M'),
  99.9000000, 129.9000000, 70.0000000, 1
FROM `products` p
WHERE p.`spu_code` = 'SPU_TEST_001';

-- 商品图集关系（验证独立关系表）
INSERT INTO `image_assets` (
  `bucket_name`, `object_key`, `origin_file_name`, `content_type`,
  `file_size`, `width`, `height`, `checksum`, `asset_type`,
  `url`, `cdn_url`, `uploader_id`, `status`, `metadata`
)
VALUES (
  'test-bucket', 'products/spu_test_001_1.jpg', 'spu_test_001_1.jpg', 'image/jpeg',
  10240, 800, 800, 'md5_test_001', 'product',
  'https://example.com/products/spu_test_001_1.jpg',
  'https://cdn.example.com/products/spu_test_001_1.jpg',
  1, 1, JSON_OBJECT('scene', 'product_gallery')
);

INSERT INTO `product_image_relations` (`product_id`, `image_asset_id`, `sort_order`, `status`)
SELECT p.`id`, i.`id`, 1, 1
FROM `products` p, `image_assets` i
WHERE p.`spu_code` = 'SPU_TEST_001'
  AND i.`object_key` = 'products/spu_test_001_1.jpg'
LIMIT 1;

-- -------- 3. 购物车/订单测试 --------
INSERT INTO `cart_items` (
  `user_id`, `sku_id`, `quantity`, `checked`,
  `price_snapshot`, `sku_snapshot`, `status`
)
SELECT
  u.`id`, s.`id`, 2, 1,
  s.`sale_price`, JSON_OBJECT('sku_code', s.`sku_code`), 1
FROM `users` u, `product_skus` s
WHERE u.`openid` = 'openid_test_001'
  AND s.`sku_code` = 'SKU_TEST_001'
LIMIT 1;

INSERT INTO `orders` (
  `order_no`, `user_id`, `order_status`, `pay_status`, `shipment_status`,
  `items_amount`, `discount_amount`, `freight_amount`, `payable_amount`, `paid_amount`,
  `address_snapshot`, `remark`, `expire_at`, `paid_at`
)
SELECT
  'ORDER_TEST_001', u.`id`, 1, 1, 1,
  199.8000000, 0.0000000, 10.0000000, 209.8000000, 0.0000000,
  JSON_OBJECT('receiver_name', '张三', 'phone', '13800000001', 'address', '天河路 100 号'),
  '测试订单',
  DATE_ADD(NOW(), INTERVAL 30 MINUTE),
  '1970-01-01 08:00:00'
FROM `users` u
WHERE u.`openid` = 'openid_test_001'
LIMIT 1;

INSERT INTO `order_items` (
  `order_id`, `order_no`, `product_id`, `sku_id`,
  `sku_name`, `sku_spec_snapshot`, `quantity`,
  `unit_price`, `discount_amount`, `pay_amount`
)
SELECT
  o.`id`, o.`order_no`, p.`id`, s.`id`,
  p.`name`, s.`spec_snapshot`, 2,
  s.`sale_price`, 0.0000000, 199.8000000
FROM `orders` o
JOIN `product_skus` s ON s.`sku_code` = 'SKU_TEST_001'
JOIN `products` p ON p.`id` = s.`product_id`
WHERE o.`order_no` = 'ORDER_TEST_001';

-- 更新订单为已支付（模拟支付成功）
UPDATE `orders`
SET `pay_status` = 2, `order_status` = 2, `paid_amount` = 209.8000000, `paid_at` = NOW()
WHERE `order_no` = 'ORDER_TEST_001';

-- 查询订单与明细
SELECT o.`order_no`, o.`order_status`, o.`pay_status`, o.`payable_amount`, oi.`sku_id`, oi.`quantity`
FROM `orders` o
JOIN `order_items` oi ON oi.`order_id` = o.`id`
WHERE o.`order_no` = 'ORDER_TEST_001';

-- -------- 4. 发货与物流测试 --------
INSERT INTO `shipments` (
  `order_id`, `order_no`, `shipment_no`,
  `carrier_code`, `carrier_name`, `waybill_no`, `express_sheet_no`,
  `shipment_status`, `pickup_status`, `cancel_status`,
  `track_pull_status`, `last_track_pull_at`, `next_track_pull_at`, `delivered_at`
)
SELECT
  o.`id`, o.`order_no`, 'SHP_TEST_001',
  'YTO', '圆通', 'WB_TEST_001', 'ES_TEST_001',
  3, 1, 1,
  1, '1970-01-01 08:00:00', NOW(), '1970-01-01 08:00:00'
FROM `orders` o
WHERE o.`order_no` = 'ORDER_TEST_001'
LIMIT 1;

INSERT INTO `shipment_tracks` (
  `shipment_id`, `order_no`, `waybill_no`, `track_time`,
  `track_status`, `track_desc`, `location`, `raw_payload`
)
SELECT
  s.`id`, s.`order_no`, s.`waybill_no`, NOW(),
  'IN_TRANSIT', '快件已发出', '广州分拨中心', JSON_OBJECT('source', 'manual_test')
FROM `shipments` s
WHERE s.`shipment_no` = 'SHP_TEST_001';

INSERT INTO `shipment_notify_logs` (
  `shipment_id`, `order_no`, `template_id`, `notify_type`, `notify_status`,
  `retry_count`, `next_retry_at`, `request_payload`, `response_payload`
)
SELECT
  s.`id`, s.`order_no`, 'tmpl_test_001', 1, 2,
  0, '1970-01-01 08:00:00',
  JSON_OBJECT('message', '已发货'),
  JSON_OBJECT('result', 'ok')
FROM `shipments` s
WHERE s.`shipment_no` = 'SHP_TEST_001';

-- 未揽收取消面单（模拟删除语义）
UPDATE `shipments`
SET `cancel_status` = 3, `shipment_status` = 5
WHERE `shipment_no` = 'SHP_TEST_001'
  AND `pickup_status` = 1;

-- -------- 5. 索引检查示例（用于 4.4）--------
-- SHOW INDEX FROM `orders`;
-- SHOW INDEX FROM `shipments`;
-- SHOW INDEX FROM `shipment_tracks`;

-- -------- 6. 可选清理（测试后执行）--------
-- 注意：为了满足“保留记录”约束，以下清理推荐改为状态流转而非 DELETE
-- UPDATE `orders` SET `order_status` = 5 WHERE `order_no` = 'ORDER_TEST_001';
-- UPDATE `products` SET `publish_status` = 3 WHERE `spu_code` = 'SPU_TEST_001';
-- UPDATE `users` SET `status` = 2 WHERE `openid` = 'openid_test_001';
