---
name: api-request-jsonc-template
description: 将 HTTP/API 接口文档、请求参数表、OpenAPI 片段、curl、请求示例或原始 JSON 转换为可直接粘贴到 data-center-system 接口管理“导入 Body JSONC”功能的请求模板，并自动把请求体标量值替换为 `${simpleName}` 通配变量。用户要求“接口文档转 JSONC”“生成 Body 模板”“请求参数变量化”“通配符 JSON”“导入 JSONC”或为 InterfaceFormDrawer 的 request-body-jsonc-import 入口准备内容时使用此技能。
---

# 接口请求 JSONC 模板

## 目标

从单个目标接口提取请求 Body，生成结构准确、无真实业务值、可被
`data-center-system/src/pages/interfaceInfo/components/InterfaceFormDrawer.vue`
的“导入 JSONC”功能解析的 JSONC 模板。所有可变标量使用简单占位符，导入时由页面自动创建普通占位符定义。

## 工作流

1. 确认目标接口。接口文档包含多个接口时，只处理用户点名的方法或路径；无法唯一确定时，先让用户指定。
2. 严格划分参数位置。只把 Body 字段写入输出，禁止把 Header、Cookie、Path 或 Query 参数混入 Body。
3. 按优先级确定结构：请求示例 > 请求 Body schema/字段表 > 接口上下文。文档冲突时保留示例结构，并在最终答复中指出冲突。
4. 有有效 JSON 请求样例时，先写入临时文件，再调用 `scripts/variableize_request_json.sh INPUT OUTPUT` 生成无注释模板。禁止用正则解析或改写 JSON。
5. 没有请求样例时，根据 Body schema 生成完整骨架：对象保留字段层级，数组保留一个代表元素，所有标量直接写成占位符字符串；不要伪造示例业务值。
6. 按 [references/conversion-rules.md](references/conversion-rules.md) 检查变量命名、数组、常量、注释和冲突。根据可靠的字段说明添加简短 `//` 行尾注释；若文档提供字段类型，注释必须同时包含类型（如 `String`、`Date`、`Number`、`Int`、`Array<Object>`）。
7. 使用 `jq` 验证去除 JSONC 注释后的结构，或将内容粘贴到请求 Body JSONC 导入框做最小验证。确认没有重复键，且每个 `${...}` 都是简单名称。

## 脚本

```text
variableize_request_json.sh INPUT_JSON OUTPUT_JSONC
```

- `INPUT_JSON`：恰好包含一个 JSON 值的文件；传 `-` 时从标准输入读取。
- `OUTPUT_JSONC`：输出位置；传 `-` 时写标准输出。
- 依赖：Bash、`jq`。
- 行为：保留字段顺序和容器结构，将全部标量替换为基于叶子字段名的 `${simpleName}`；数组下标不进入变量名；只有叶子字段名冲突时才使用上级路径消歧。

示例：

```bash
<skill-directory>/scripts/variableize_request_json.sh \
  /tmp/create-order-request.json create_order_request.jsonc
```

脚本只处理已经提取出的有效 JSON。任意排版的 Markdown、HTML 或参数表由当前 Agent 按工作流解析，不把脆弱的文档解析逻辑塞进脚本。

## 输出约束

- 输出根结构必须与接口 Body 一致，不强制为对象。
- 所有占位符必须位于 JSON 字符串中，例如 `"${order_id}"`；不得输出裸 `${order_id}`。
- 只使用符合 `^[A-Za-z_$][\w$]*$` 的简单变量名。不要生成函数、点路径、空格、连字符或其他复杂表达式。
- 默认替换数字、布尔、字符串和 `null`；仅当文档明确声明字段是固定协议常量，或用户要求保留常量时，才恢复原始字面量。
- 保留空对象与空数组。不得猜测其内部字段；在注释或最终答复中标明文档未提供元素结构。
- 不保留 token、密码、密钥、身份证号等真实值；变量化之后也不要在注释或答复中复述它们。
- JSONC 可以有注释和尾随逗号，但为了跨工具兼容，默认不用尾随逗号。注释只写可靠的字段含义、字段类型和明确规则，不猜测业务规则。
- 有参数表、schema、OpenAPI 类型或字段说明时，字段注释格式优先为 `字段说明，类型`；有枚举、长度、必填条件等规则时追加为 `字段说明，类型；规则`。
- 只有请求样例、没有契约类型时，可按 JSON 字面量推断并标注为 `推断类型`，例如 `// 数量，Number（推断）`；不能从空字符串、`null`、空对象或空数组臆测类型。

## 交付

默认输出一个可直接粘贴的 `jsonc` 代码块；用户指定文件时写入该文件。若用户要求落盘但未指定名称，使用 `<method-or-endpoint>_request.jsonc`。

最终答复简要说明目标接口、输入依据、输出位置、生成的普通变量数量、是否已补充字段类型注释，以及文档中缺失或冲突的 Body 结构。
