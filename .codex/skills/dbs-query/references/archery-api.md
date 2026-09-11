# Archery API 契约

CLI 基于 `https://dbs.poi-t.cn` 当前使用的 Archery 接口。所有接口响应都应满足：

```json
{
  "status": 0,
  "msg": "ok",
  "data": null
}
```

`status` 非 `0`、返回 HTML 或 HTTP 401/403 均视为失败。HTML 通常表示 Session 已失效。

## 认证

### 获取 CSRF Cookie

```http
GET /login/
```

读取响应 Cookie 中的 `csrftoken`。

### 登录

```http
POST /authenticate/
Content-Type: application/x-www-form-urlencoded
X-CSRFToken: <csrftoken>

username=<username>&password=<password>
```

保存登录后的 `sessionid` 和最新 `csrftoken`。不要保存浏览器统计 Cookie。

## 实例发现

```http
GET /group/user_all_instances/?tag_codes%5B%5D=can_read
```

`data` 是当前用户可读实例数组：

```json
[
  {
    "id": 80,
    "type": "master",
    "db_type": "mysql",
    "instance_name": "示例生产MySQL"
  }
]
```

字段用途：

| 字段 | 用途 |
| --- | --- |
| `id` | 本地缓存和 Target 使用的稳定标识 |
| `instance_name` | Archery 后续接口的请求参数及展示名 |
| `db_type` | 区分 `mysql`、`pgsql`、`redis` |
| `type` | Archery 返回的主从类型 |

## 数据库发现

```http
GET /instance/instance_resource/?instance_name=<url-encoded-name>&resource_type=database
```

`data` 是当前用户在该实例可读的数据库名称数组：

```json
[
  "example-app",
  "example-data"
]
```

数据库列表按实例 ID 缓存。请求仍传 `instance_name`；缓存中名称与实例缓存不一致时重新获取。

## SQL 查询

```http
POST /query/
Content-Type: application/x-www-form-urlencoded
```

表单字段：

| 字段 | 来源 |
| --- | --- |
| `instance_name` | Target |
| `db_name` | Target |
| `schema_name` | Target，可为空 |
| `tb_name` | CLI 参数或 SQL 中识别的首个表 |
| `sql_content` | 经过本地只读校验的 SQL |
| `limit_num` | CLI 限制，1 到 1000 |

## 表结构

```http
POST /instance/describetable/
Content-Type: application/x-www-form-urlencoded
```

表单字段为 `instance_name`、`db_name`、`schema_name`、`tb_name`。

## 必要请求头

- `Accept: application/json, text/javascript, */*; q=0.01`
- `Origin: <base-url>`
- `Referer: <base-url>/sqlquery/`
- `X-Requested-With: XMLHttpRequest`
- `X-CSRFToken: <csrftoken>`
- `Cookie: csrftoken=<token>; sessionid=<session>`

不要复制浏览器的 `sec-ch-*`、Google Analytics Cookie 或其他非必要请求头。
