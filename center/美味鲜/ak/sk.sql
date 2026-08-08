-- 1. 新增 AK/SK 密钥   广东美味鲜调味食品有限公司
-- 使用场景：创建新的 OpenApi 调用凭证，并授权 eid f940d0996bb44eb3ba683c6bf1e9a361。
-- 业务说明：中台系统调用博依特 OpenApi。
INSERT INTO `poit-commons`.`client_details` (
  `app_key`,
  `secret_key`,
  `eids`,
  `remark`
)
VALUES (
  'LG33BlFwPbz4AvSA',
  'vZm55IN5n2Iad90z8SChwNS4w6B3jOfl',
  'f940d0996bb44eb3ba683c6bf1e9a361',
  '中台系统调用博依特 OpenApi'
);

-- 2. 复用旧 AK 追加 eid 权限
-- 使用场景：将 <请替换为旧ak> 替换为已有 app_key。
-- 已存在该 eid 时保持原值，避免重复拼接；执行后约 30 分钟生效。
UPDATE `poit-commons`.`client_details`
SET `eids` = CASE
  WHEN `eids` IS NULL OR `eids` = '' THEN 'f940d0996bb44eb3ba683c6bf1e9a361'
  WHEN FIND_IN_SET(
    'f940d0996bb44eb3ba683c6bf1e9a361',
    REPLACE(`eids`, ' ', '')
  ) > 0 THEN `eids`
  ELSE CONCAT(`eids`, ',', 'f940d0996bb44eb3ba683c6bf1e9a361')
END
WHERE `app_key` = '<请替换为旧ak>';

-- 3. 查询 eid 是否已有权限
-- 使用场景：确认该企业 eid 当前已授权给哪些 app_key。
SELECT *
FROM `poit-commons`.`client_details`
WHERE FIND_IN_SET(
  'f940d0996bb44eb3ba683c6bf1e9a361',
  REPLACE(`eids`, ' ', '')
) > 0;


-- 1. 新增 AK/SK 密钥  阳西美味鲜食品有限公司
-- 使用场景：创建新的 OpenApi 调用凭证，并授权 eid f0d1a66ef92f459d93e47588b9c41e79。
-- 业务说明：中台系统调用博依特 OpenApi。
INSERT INTO `poit-commons`.`client_details` (
  `app_key`,
  `secret_key`,
  `eids`,
  `remark`
)
VALUES (
  'EebD2PUVIXBtXtTe',
  'UoVU0tZunDphy7Lvmok0jbM0PiuHgRmE',
  'f0d1a66ef92f459d93e47588b9c41e79',
  '中台系统调用博依特 OpenApi'
);

-- 2. 复用旧 AK 追加 eid 权限
-- 将 <请替换为旧ak> 替换为已有 app_key；已有该 eid 时不重复追加。
-- 复用旧密钥受缓存影响，SQL 执行后约 30 分钟生效。
UPDATE `poit-commons`.`client_details`
SET `eids` = CASE
  WHEN `eids` IS NULL OR `eids` = '' THEN 'f0d1a66ef92f459d93e47588b9c41e79'
  WHEN FIND_IN_SET(
    'f0d1a66ef92f459d93e47588b9c41e79',
    REPLACE(`eids`, ' ', '')
  ) > 0 THEN `eids`
  ELSE CONCAT(`eids`, ',', 'f0d1a66ef92f459d93e47588b9c41e79')
END
WHERE `app_key` = '<请替换为旧ak>';

-- 3. 查询 eid 是否已有权限
SELECT *
FROM `poit-commons`.`client_details`
WHERE FIND_IN_SET(
  'f0d1a66ef92f459d93e47588b9c41e79',
  REPLACE(`eids`, ' ', '')
) > 0;



-- 1. 新增 AK/SK 密钥      广东厨邦食品有限公司
-- 使用场景：创建新的 OpenApi 调用凭证，并授权 eid 117f62346fa84e528cd357998aee1030。
INSERT INTO `poit-commons`.`client_details` (
  `app_key`,
  `secret_key`,
  `eids`,
  `remark`
)
VALUES (
  'rQT0kUIIwbOI20Pz',
  'CuLOOjQUv8TGMjRcFsYVU8x4Yorn043W',
  '117f62346fa84e528cd357998aee1030',
  '中台系统调用博依特 OpenApi'
);

-- 2. 复用旧 AK 追加 eid 权限  
-- 将 <请替换为旧ak> 替换为已有 app_key；已有该 eid 时不重复追加。
-- 复用旧密钥受缓存影响，SQL 执行后约 30 分钟生效。
UPDATE `poit-commons`.`client_details`
SET `eids` = CASE
  WHEN `eids` IS NULL OR `eids` = '' THEN '117f62346fa84e528cd357998aee1030'
  WHEN FIND_IN_SET(
    '117f62346fa84e528cd357998aee1030',
    REPLACE(`eids`, ' ', '')
  ) > 0 THEN `eids`
  ELSE CONCAT(`eids`, ',', '117f62346fa84e528cd357998aee1030')
END
WHERE `app_key` = '<请替换为旧ak>';

-- 3. 查询 eid 是否已有权限
SELECT *
FROM `poit-commons`.`client_details`
WHERE FIND_IN_SET(
  '117f62346fa84e528cd357998aee1030',
  REPLACE(`eids`, ' ', '')
) > 0;