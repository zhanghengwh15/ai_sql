---
name: task-field-expression
description: 为 data-center-system 任务字段映射生成、检查或解释“字段表达式”。当用户需要填写采集任务 data-center-system/src/pages/collectTask/components/TaskFormDrawer.vue 或出仓任务 data-center-system/src/pages/outboundTask/components/DockTaskFormDrawer.vue 中“字段映射/返回字段映射”区域里映射规则为“表达式”的输入框，或需要根据接口返回字段、占位符、请求/响应上下文、poit-data-center-cloud 后端 ExpressionHelper/JEXL 自定义函数来拼接数据库字段值时使用；也适用于用户说“字段表达式怎么写”“任务表达式”“采集任务表达式”“出仓任务表达式”“映射值表达式”“返回字段映射表达式”“根据我的想法找表达式”。
---

# 任务字段表达式

## 核心判断

目标是生成一个能返回“数据库字段值”的表达式。这个表达式写在任务表单的字段映射区域里，当某一行的“映射规则”选择“表达式”时，右侧输入框会把内容保存到 `TaskMappingRuleDTO.expression`。

主要入口：

- 采集任务前端：`data-center-system/src/pages/collectTask/components/TaskFormDrawer.vue`
- 出仓任务前端：`data-center-system/src/pages/outboundTask/components/DockTaskFormDrawer.vue`
- 前端字段：`form.taskParam.fieldsMapping[].expression`
- 后端映射 DTO：`poit-data-center-cloud/poit-data-center-cloud-api/src/main/java/com/poit/data/center/cloud/api/dto/req/taskconfig/TaskMappingRuleDTO.java`
- 后端执行位置：
  - `poit-data-center-cloud/poit-data-center-cloud-biz/src/main/java/com/poit/data/center/cloud/biz/core/task/handler/taskresp/AbstractTaskRespHandler.java`
  - `poit-data-center-cloud/poit-data-center-cloud-biz/src/main/java/com/poit/data/center/cloud/biz/utils/helper/TaskRecordHelper.java`

后端对字段表达式执行：

```text
ExpressionHelper.parse(field.getExpression(), variable, retParam)
```

也就是说，表达式上下文同时包含“当前返回行 retParam 的字段”和“整次请求/响应/占位符变量”。

## 不要混淆

本 skill 只处理任务字段映射区域中“映射规则=表达式”的字段值表达式，适用于采集任务和出仓任务。

不要把它和 `taskParam.pendingProcessingDataExpression` 混在一起。后者是“待处理数据表达式/执行条件”，会走数据字典条件校验和 SQL 条件生成，不是 JEXL 字段表达式。

## 使用流程

1. 先问清楚目标数据库字段要存什么：直接取接口字段、拼接多个字段、格式化时间、取请求参数、取占位符、固定前缀，还是做空值兜底。
2. 如果只是一对一取字段，建议用“字段映射”，不用表达式。
3. 如果需要计算、拼接、转换或兜底，选择“表达式”，并生成一条能返回单个值的 JEXL 表达式。
4. 如果表达式用函数，读取 `references/function-reference.md`。
5. 如果用户只描述业务想法，先从 `references/recipes.md` 找最接近的模板，再替换字段名。
6. 输出可直接粘贴的表达式，并说明用到了哪些变量。

## 可用变量

字段表达式最重要的变量是“当前返回行”的字段。后端会把 `retParam` 直接铺到根上下文，所以通常可以直接写接口返回字段别名或路径：

| 变量写法 | 含义 | 示例 |
|---|---|---|
| `sheetId` | 当前返回行字段，通常来自接口字段别名 `enName` | `sheetId` |
| `orgId` | 当前返回行字段 | `orgId` |
| `produceTaskId` | 当前返回行字段 | `produceTaskId` |
| `shiftName` | 当前返回行字段 | `shiftName` |
| `respBody` | 整个响应体 | `respBody.data.total` |
| `respHeader` | 响应头 | `respHeader.traceId` |
| `reqParam` | 请求 URL/query 参数 | `reqParam.workDate` |
| `reqHeader` | 请求头 | `reqHeader.tenantId` |
| `reqBody` | 请求体 | `reqBody.bizDate` |
| `placeholder` | 当前任务占位符 | `placeholder.workDate` |
| `syncProgressPlaceholder` | 增量进度 | `syncProgressPlaceholder` |
| `syncPageNumPlaceholder` | 分页进度 | `syncPageNumPlaceholder` |

优先使用接口字段别名，比如 `sheetId`、`orgId`。如果没有别名，使用接口字段路径，比如 `data.id`、`[0]` 这类路径要结合接口字段配置确认。采集任务和出仓任务都遵循这个原则。

## 常用模板

直接取当前返回行字段：

```text
sheetId
```

两个字段拼接：

```text
sheetId + "-" + orgId
```

加固定前缀：

```text
"SHEET-" + sheetId
```

取请求日期作为字段值：

```text
reqParam.workDate
```

取占位符日期作为字段值：

```text
placeholder.workDate
```

时间格式化：

```text
timeFormatToStr(workDate, "yyyy-MM-dd")
```

时间加一天：

```text
addFormatToStr(workDate, "D", 1, "yyyy-MM-dd")
```

时间戳转日期时间：

```text
formatToStr(createTimestamp, "yyyy-MM-dd HH:mm:ss")
```

URL 解码：

```text
decode(encodedName)
```

字段转字符串：

```text
toString(sheetId)
```

提取字符串中的数字：

```text
extractNumber(batchNo, -1)
```

## 语法检查

- 不要写 `${...}`，只写原始表达式。
- 字符串常量要加引号：`"SHEET-" + sheetId`。
- 当前返回行字段通常直接写字段名，不要加 `retParam.`，因为后端没有把它以 `retParam` 名称放进上下文。
- 如果要拿整次响应体，才使用 `respBody.xxx`。
- 表达式要返回单个值；不要返回对象或数组，除非目标字段就是 JSON 字符串并做了 `toJsonString(...)`。
- 如果目标字段勾选“作为对比”，表达式结果会参与更新/去重比较；计算结果不稳定时不要作为对比字段。
- `currentDateTime()`、`currentTimestamp()`、随机数、UUID、雪花 ID 这类不稳定值通常不要作为对比字段。
- 表达式解析失败时，该字段不会被设置为表达式结果；优先写简单可解释的表达式。

## 回复格式

优先用中文给出：

```text
推荐表达式：
<expression>

说明：
<一句话解释字段来源和转换逻辑>
```

如果用户只说想法但没给字段：

```text
我需要确认接口字段别名。请给出这一行可用字段，比如 sheetId、orgId、workDate，或者发一段接口返回示例。

常见可选：
1. 直接取字段：sheetId
2. 拼接字段："SHEET-" + sheetId
3. 日期格式化：timeFormatToStr(workDate, "yyyy-MM-dd")
```
