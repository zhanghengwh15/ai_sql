# 任务字段表达式函数参考

任务字段表达式使用后端表达式引擎：Apache JEXL + `poit-data-center-cloud-expression` 自定义函数。采集任务和出仓任务的 `fieldsMapping[].expression` 都按这套规则理解。

函数来源：

`poit-data-center-cloud/poit-data-center-cloud-expression/src/main/java/com/poit/data/center/cloud/expression/function`

自定义函数都继承 `CustomFunction`。表达式里能调用的名字，是函数类构造器里 `super("...")` 的别名。

## 任务字段表达式最常用函数

| 函数 | 写法 | 用途 |
|---|---|---|
| `toString` | `toString(value)` | 转字符串。 |
| `toInteger` | `toInteger(value)` | 整数字符串转整数；不是整数则返回原值。 |
| `toBigDecimal` | `toBigDecimal(value)` | 数字字符串转 `BigDecimal`；不是数字则返回原值。 |
| `timeFormatToStr` | `timeFormatToStr(time, format?)` | 时间字符串转指定格式字符串。 |
| `formatToStr` | `formatToStr(timestamp, format?)` | 秒级/毫秒级时间戳转字符串。 |
| `formatToTimestamp` | `formatToTimestamp(time, outputType?)` | 时间字符串转时间戳；`0` 毫秒，默认秒。 |
| `addFormatToStr` | `addFormatToStr(time, unit, offset, format?)` | 时间偏移后转字符串。 |
| `currentDateTime` | `currentDateTime(format?)` | 当前时间字符串。 |
| `currentTimestamp` | `currentTimestamp(type?)` | 当前时间戳；`0` 毫秒，默认秒。 |
| `decode` | `decode(value, charset?)` | URL 解码。 |
| `encode` | `encode(value, charset?)` | URL 编码。 |
| `substring` | `substring(value, start, end?)` | 截取字符串。 |
| `trimString` | `trimString(value)` | 去首尾空白。 |
| `removeAllEmpty` | `removeAllEmpty(value)` | 删除空格。 |
| `extractNumber` | `extractNumber(value, index?)` | 提取数字；`-1` 取最后一段。 |
| `extractString` | `extractString(value, index?)` | 提取英文字母；`-1` 取最后一段。 |
| `toLowerCase` | `toLowerCase(value)` | 转小写。 |
| `toUpperCase` | `toUpperCase(value)` | 转大写。 |
| `toJsonString` | `toJsonString(value)` | 对象转 JSON 字符串。 |
| `toJSON` | `toJSON(value)` | JSON 字符串转对象/数组。 |

## 时间单位

时间偏移函数使用：

| 代码 | 含义 |
|---|---|
| `Y` | 年 |
| `M` | 月 |
| `D` | 日 |
| `H` | 小时 |
| `MIN` | 分钟 |
| `S` | 秒 |

## 时间函数示例

当前时间：

```text
currentDateTime("yyyy-MM-dd HH:mm:ss")
```

字段时间格式化：

```text
timeFormatToStr(workDate, "yyyy-MM-dd")
```

字段时间加一天：

```text
addFormatToStr(workDate, "D", 1, "yyyy-MM-dd")
```

时间戳转字符串：

```text
formatToStr(createTime, "yyyy-MM-dd HH:mm:ss")
```

字符串时间转秒级时间戳：

```text
formatToTimestamp(workDate, 1)
```

字符串时间转毫秒级时间戳：

```text
formatToTimestamp(workDate, 0)
```

## 字符串函数示例

固定前缀：

```text
"ORG-" + orgId
```

去空格：

```text
trimString(courseName)
```

提取批次号最后一段数字：

```text
extractNumber(batchNo, -1)
```

截取前 8 位：

```text
substring(sheetId, 0, 8)
```

URL 解码：

```text
decode(encodedName)
```

## 集合与比较函数

这些函数可用，但任务字段表达式里不如增量表达式常见：

| 函数 | 写法 | 说明 |
|---|---|---|
| `max` | `max(values...)` 或 `max(jsonArray)` | 字符串比较最大值。 |
| `min` | `min(values...)` 或 `min(jsonArray)` | 字符串比较最小值。 |
| `maxObject` | `maxObject(jsonArray, fieldPath)` | 从对象数组按字段取最大值。 |
| `minObject` | `minObject(jsonArray, fieldPath)` | 从对象数组按字段取最小值。 |
| `in` | `in(item, jsonArray)` | 判断是否在 JSON 数组中。 |

## Hutool 反射工具

这些别名会通过反射调用 Hutool 静态工具方法。第一个参数是方法名，后续参数传给该方法：

- `DateUtil(methodName, args...)`
- `StrUtil(methodName, args...)`
- `NumberUtil(methodName, args...)`
- `JSONUtil(methodName, args...)`
- `RandomUtil(methodName, args...)`
- `URLUtil(methodName, args...)`

示例：

```text
StrUtil("isBlank", courseName)
```

优先使用项目封装函数，比如 `timeFormatToStr`、`addFormatToStr`、`decode`、`extractNumber`。只有明确需要 Hutool 且确认方法签名时，才使用反射工具。

## 系统函数和表达式的区别

字段映射里还有“系统函数”规则，后端由 `FieldUtils.getMappingSystemFunctionValue(functionType, functionFormat)` 处理，常见类型来自 `MappingSystemFunctionEnum`：

| functionType | 含义 | functionFormat |
|---|---|---|
| `date` | 当前时间字符串 | 日期格式，如 `yyyy-MM-dd HH:mm:ss` |
| `timestamp` | 当前毫秒时间戳 | 不重要 |
| `uuid` | 32 位 UUID | 不需要 |
| `snowflake` | 雪花 ID | 不需要 |
| `random_number` | 随机数字 | 长度 |
| `random_string` | 随机字符串 | 长度 |

如果用户选择“表达式”，不要填写 `functionType`，而是直接写 JEXL 表达式，例如 `currentDateTime("yyyy-MM-dd")`。
