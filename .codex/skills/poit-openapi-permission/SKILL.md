---
name: poit-openapi-permission
description: 博依特 OpenApi 接口权限 SQL 生成与核验流程。用户要求新增 OpenApi AK/SK、复用旧 AK/SK 增加 eid 授权、确认 eid 是否有接口权限、生成 poit-commons.client_details 写入或查询 SQL 时使用；直接一次性给出新增、复用旧密钥、查询三种带中文注释的 SQL，并按需生成合规 AK/SK，生成后必须用 bash 校验长度和字符集。
---

# 博依特 OpenApi 权限

## 概述

为 `poit-commons.client_details` 直接生成三种 OpenApi 权限 SQL：新增 AK/SK、复用旧 AK/SK 追加 eid、查询 eid 是否有权限。

## 固定输出要求

- 不要先追问用户操作类型；每次都直接给出三段 SQL：`新增 AK/SK`、`复用旧 AK/SK`、`查询 eid 是否有权限`。
- SQL 必须写中文注释，说明每个参数如何替换、何时使用、注意事项。
- 如果用户提供了 `eid`、旧 `ak`、`业务描述`，直接替换进 SQL。
- 如果用户没有提供 `业务描述`，默认使用 `中台系统调用博依特 OpenApi`。
- 如果用户没有提供 `ak`/`sk`，为“新增 AK/SK”场景生成随机 `ak` 和 `sk`，生成后必须实际运行 bash 校验长度和字符集。
- 生成 `ak`/`sk` 后不能只口头说明“已验证”；必须在当前终端运行 bash 校验脚本，确认 `ak` 长度为 16、`sk` 长度为 32，再把校验结果写进最终输出。
- 如果用户提供了 `ak`/`sk`，也要按长度和字符集规则检查；不合规时在输出中提示用户，不要静默修改用户提供的值。
- 如果用户没有提供 `eid` 或旧 `ak`，不要追问；在 SQL 中保留清晰的待替换值，例如 `'<请替换为企业eid>'`，并用注释提示用户替换。
- 写操作默认只生成 SQL；只有用户明确要求执行并确认目标环境后，才考虑执行。
- 字符串值使用单引号；业务描述中的单引号要转义为两个单引号。
- 最后必须提示：执行 SQL 时要选择 `poit-commons` 数据库。

## 参数规则

- `ak`：16 位随机字符串，只包含数字、大小写字母。
- `sk`：32 位随机字符串，只包含数字、大小写字母。
- `eid`：申请访问的企业 eid；多个 eid 用英文逗号连接，例如 `1001,1002`。
- `业务描述`：申请原因或业务说明；用户未提供时默认使用 `中台系统调用博依特 OpenApi`。

生成 `ak`/`sk` 时必须使用 bash 脚本自检长度和字符集。校验通过后才能把生成值写入 SQL：

```bash
ak="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 16 | head -n 1)"
sk="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | fold -w 32 | head -n 1)"

[[ ${#ak} -eq 16 && "$ak" =~ ^[A-Za-z0-9]{16}$ ]] || {
  echo "ak 校验失败：length=${#ak}, value=$ak" >&2
  exit 1
}

[[ ${#sk} -eq 32 && "$sk" =~ ^[A-Za-z0-9]{32}$ ]] || {
  echo "sk 校验失败：length=${#sk}, value=$sk" >&2
  exit 1
}

printf 'ak=%s length=%d OK\nsk=%s length=%d OK\n' "$ak" "${#ak}" "$sk" "${#sk}"
```

## 输出模板

按下面结构输出。若已有真实参数，替换模板中的待替换值。

```sql
-- 执行提示：请在 DBS 中选择 `poit-commons` 数据库后再执行以下 SQL。

-- 1. 新增 AK/SK 密钥
-- 使用场景：给新的 OpenApi 调用方创建一组新的 app_key/secret_key，并授权访问指定 eid。
-- 注意：ak 必须为 16 位数字/大小写字母；sk 必须为 32 位数字/大小写字母。
-- 注意：多个 eid 使用英文逗号分隔，例如 '1001,1002'。
INSERT INTO `poit-commons`.`client_details` (`app_key`, `secret_key`, `eids`, `remark`)
VALUES (
  '<新增ak，未提供时生成16位随机字符串>',
  '<新增sk，未提供时生成32位随机字符串>',
  '<请替换为企业eid>',
  '中台系统调用博依特 OpenApi'
);

-- 2. 复用旧 AK/SK 密钥
-- 使用场景：已有可复用的旧 ak，只需要给这组旧密钥追加新的 eid 权限。
-- 注意：这里不需要 sk；只需要旧 ak 和本次要追加的 eid。
-- 注意：复用旧密钥受缓存影响，SQL 执行约 30 分钟后生效。
UPDATE `poit-commons`.`client_details`
SET eids = CONCAT(eids, ',', '<请替换为要追加的企业eid>')
WHERE app_key = '<请替换为旧ak>';

-- 3. 查询 eid 是否已有权限
-- 使用场景：确认某个 eid 是否已经配置在 client_details.eids 中。
-- 注意：将下面的 eid 替换为具体企业 eid；多个 eid 建议分别查询。
SELECT *
FROM `poit-commons`.`client_details`
WHERE eids LIKE '%<请替换为企业eid>%';
```

## 输出补充

SQL 后简短列出本次参数：

- `新增 ak`：如果生成了随机值，写出生成值。
- `新增 sk`：如果生成了随机值，写出生成值。
- `AK/SK 校验`：写明已实际运行 bash 校验脚本，并列出脚本输出中的 `ak length=16 OK`、`sk length=32 OK`。
- `eid`：用户提供则写真实值；未提供则写“待替换”。
- `旧 ak`：用户提供则写真实值；未提供则写“待替换”。
- `业务描述`：用户提供则写真实值；未提供则写 `中台系统调用博依特 OpenApi`。
- `执行提示`：明确写出“请在 DBS 中选择 `poit-commons` 数据库后执行 SQL”。
