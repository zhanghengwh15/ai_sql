#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将JSON中的expression字段从snake_case转换为camelCase
"""

import json

def snake_to_camel(snake_str):
    """
    将snake_case转换为camelCase
    例如: roll_number -> rollNumber, inner_head1 -> innerHead1
    """
    if not snake_str or '_' not in snake_str:
        return snake_str
    components = snake_str.split('_')
    # 第一个组件保持小写，后续组件首字母大写
    return components[0] + ''.join(x.capitalize() for x in components[1:])

def convert_expressions_to_camelcase(input_file):
    """
    读取JSON文件，将所有expression字段转换为驼峰形式
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 转换每个对象的expression字段
    count = 0
    for item in data:
        if 'expression' in item and item['expression']:
            original = item['expression']
            converted = snake_to_camel(original)
            if original != converted:
                item['expression'] = converted
                count += 1
    
    # 保存转换后的JSON
    with open(input_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print(f"转换完成！已将 {count} 个字段的expression转换为驼峰形式")

if __name__ == '__main__':
    input_file = 'field_mapping_result.json'
    convert_expressions_to_camelcase(input_file)
