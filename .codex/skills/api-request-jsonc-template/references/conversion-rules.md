# 转换规则

## 信息边界

只处理目标接口的请求 Body。以下内容不得进入 Body JSONC：

- URL 路径参数和 Query 参数
- Header、Cookie、鉴权字段
- 响应字段和响应示例
- DTO 外层框架字段，除非它们确实由客户端作为 Body 发送

文档只有 `application/x-www-form-urlencoded`、`multipart/form-data` 或无 Body 的 GET 请求时，不伪造 JSON Body；说明该接口不适用于 Body JSONC 导入。

## 结构来源

按以下优先级合并信息：

1. 请求示例决定根类型、字段拼写、顺序和嵌套关系。
2. 请求 Body schema 或字段表补充示例未覆盖的字段和说明。
3. 接口上下文只补充能够可靠确认的语义。

请求示例与 schema 冲突时，不静默选择：输出遵循示例结构，并报告字段或类型差异。没有示例时生成 schema 的完整骨架，包括可选字段；用户要求“最小请求”时才只保留必填字段。

## 变量命名

默认使用叶子字段名作为占位符，避免把集合、包装对象等层级名带入变量名。数组下标不进入变量名：

| 字段路径 | 占位符 |
| --- | --- |
| `orderId` | `${orderId}` |
| `filter.startTime` | `${startTime}` |
| `items[0].skuCode` | `${skuCode}` |
| `items[1].skuCode` | `${skuCode}` |
| `dataList[0].sheetBatchNo` | `${sheetBatchNo}` |

把变量名中的非 ASCII 字母、数字、`_`、`$` 替换为 `_`。变量名以数字开头时加 `value_` 前缀。空路径使用 `value`。

转换后检查重名：

- 同一数组元素结构产生相同变量名是预期行为。
- 不同业务路径因字符清洗产生同名时，手工改成不同且有语义的简单名称。
- 同一个叶子字段名出现在不同对象中且含义不同，才使用必要上级路径消歧，例如 `source.id` → `${source_id}`、`target.id` → `${target_id}`。
- 不要仅因为字段在数组、`dataList`、`items`、`records` 等集合包装内，就给变量名加 `dataList_`、`items_`、`records_` 前缀。

## 值转换

默认把每个标量替换为 JSON 字符串占位符：

```jsonc
{
  "orderId": "${orderId}", // 订单编号，String
  "filter": {
    "startTime": "${startTime}" // 查询开始时间，Date
  },
  "items": [
    {
      "skuCode": "${skuCode}", // SKU 编码，String
      "quantity": "${quantity}" // 数量，Number；运行时由占位符提供
    }
  ]
}
```

即使原值是 Number、Boolean 或 Null，也输出带双引号的占位符。页面通过字符串扫描 `${simpleName}` 并创建占位符；裸变量不是合法 JSONC。

只有文档明确使用“固定”“恒为”“必须传字面量 X”等表述，或用户明确要求时，才保留协议常量：

```jsonc
{
  "version": "v1", // 固定协议版本
  "orderId": "${orderId}" // 订单编号
}
```

枚举字段不是固定常量。除非文档声明唯一固定值，否则仍转换为变量，并在注释中列出允许值。

## 字段注释与类型

有可靠字段说明时，为每个 Body 字段尽量添加行尾注释。注释用于请求 Body JSONC 导入后自动填充占位符中文名和备注，因此字段类型不能省略。

注释优先格式：

```text
// 字段说明，类型
// 字段说明，类型；规则、枚举或条件
```

类型来源优先级：

1. 参数表或 schema 的 `数据类型` / `type` / `format`。
2. OpenAPI schema：`string + date/date-time` 写作 `Date`；`integer` 可按文档写作 `Int`；`number` 写作 `Number`；数组对象写作 `Array<Object>`。
3. 仅有请求样例时，可从非空 JSON 字面量推断 `String`、`Number`、`Boolean`、`Object`、`Array`，并标注 `（推断）`。

不能从以下信息臆测类型：空字符串、`null`、空对象、空数组、字段名猜测。此时只写字段说明，或在最终答复中说明类型缺失。

示例：

```jsonc
{
  "eid": "${eid}", // 企业EID，String
  "sendDate": "${sendDate}", // 报工日期，Date
  "uniqueType": "${uniqueType}", // 第三方系统唯一标识存在时处理方式，Int；0直接报错，1先退回再报工，2只退回不报工
  "output": "${output}" // 报工数量，Number
}
```

如果注释开头是纯枚举说明而不是字段说明，例如 `// 0报错，1跳过`，应补成 `字段说明，类型；0报错，1跳过`，避免导入器把枚举文本误当中文名。

## 数组与空容器

- 示例数组非空时保留全部元素，以免丢失异构结构；相同字段路径复用同一变量名。
- 只有 schema 没有示例时，为数组生成一个代表元素。
- 原始空数组或空对象保持为空，不猜测成员。
- 原始字符串内部看起来像 JSON 时默认保持为一个变量；仅当文档明确声明 Body 中该字段承载序列化 JSON，且用户要求展开时再处理。

## 导入兼容性

请求 Body 导入器接受注释和尾随逗号，应用后会格式化为严格 JSON 并移除注释。普通变量必须匹配：

```text
^[A-Za-z_$][\w$]*$
```

以下会被视为复杂表达式，不会自动新增普通占位符：

```text
${filter.startTime}
${start-time}
${formatToStr(now(), "yyyy-MM-dd")}
```

系统占位符 `${syncProgressPlaceholder}` 和 `${syncPageNumPlaceholder}` 会被识别为系统变量，不会新增为普通占位符。只有接口确实需要增量或分页语义时才使用它们，不能根据字段名自行替换。
