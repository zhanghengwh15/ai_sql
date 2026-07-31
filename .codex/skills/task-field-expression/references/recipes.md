# 任务字段表达式场景模板

根据用户描述选择最接近的模板，替换字段名即可。

## 直接取值

想把接口字段 `sheetId` 写入数据库字段：

```text
sheetId
```

想把请求参数 `workDate` 写入数据库字段：

```text
reqParam.workDate
```

想把任务占位符 `workDate` 写入数据库字段：

```text
placeholder.workDate
```

## 拼接编码

生成业务唯一键：

```text
sheetId + "-" + orgId + "-" + courseId
```

加固定前缀：

```text
"SHEET-" + sheetId
```

日期加班次组成批次：

```text
timeFormatToStr(workDate, "yyyyMMdd") + "-" + shiftId
```

## 日期处理

接口返回 `workDate` 是完整时间，只保存日期：

```text
timeFormatToStr(workDate, "yyyy-MM-dd")
```

保存下一天日期：

```text
addFormatToStr(workDate, "D", 1, "yyyy-MM-dd")
```

保存上一天日期：

```text
addFormatToStr(workDate, "D", -1, "yyyy-MM-dd")
```

时间戳转日期时间：

```text
formatToStr(createTimestamp, "yyyy-MM-dd HH:mm:ss")
```

当前时间作为创建时间：

```text
currentDateTime("yyyy-MM-dd HH:mm:ss")
```

## 清洗转换

字段去首尾空格：

```text
trimString(courseName)
```

字段转大写：

```text
toUpperCase(orgCode)
```

字段转小写：

```text
toLowerCase(orgCode)
```

数字字符串转整数：

```text
toInteger(quantity)
```

数字字符串转高精度数字：

```text
toBigDecimal(amount)
```

URL 解码名称：

```text
decode(courseName)
```

## 提取字符

从字符串里提取所有数字：

```text
extractNumber(batchNo)
```

从字符串里提取最后一段数字：

```text
extractNumber(batchNo, -1)
```

截取字符串：

```text
substring(sheetId, 0, 8)
```

## 采集/出仓任务常见字段

上游报工 ID：

```text
sheetId
```

机构 ID：

```text
orgId
```

生产任务 ID：

```text
produceTaskId
```

班次 ID：

```text
shiftId
```

班次名称：

```text
shiftName
```

班组 ID：

```text
courseId
```

班组名称：

```text
courseName
```

如果要把上游报工 ID 加日期做唯一键：

```text
sheetId + "-" + reqParam.workDate
```

出仓任务若字段别名类似 `orderNo`、`materialCode`、`batchNo`，也直接替换：

```text
orderNo + "-" + materialCode + "-" + batchNo
```
