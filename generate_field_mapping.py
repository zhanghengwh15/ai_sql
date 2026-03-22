#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从field.json生成字段映射JSON
"""

import json

# 需要忽略的字段列表
IGNORE_FIELDS = {
    'id', 'rec_status', 'create_time', 'create_by', 
    'modify_time', 'modify_by', 'eid', 'task_record_id'
}

def snake_to_camel(snake_str):
    """
    将snake_case转换为camelCase
    例如: roll_number -> rollNumber, inner_head1 -> innerHead1
    """
    if not snake_str or '_' not in snake_str:
        return snake_str
    components = snake_str.split('_')
    return components[0] + ''.join(x.capitalize() for x in components[1:])

def convert_field(field):
    """
    转换单个字段定义
    """
    physical_name = field.get('physicalName', '')
    
    # 如果字段在忽略列表中，返回None
    if physical_name in IGNORE_FIELDS:
        return None
    
    return {
        "fieldId": field.get('id'),
        "fieldName": physical_name,
        "fieldCnName": field.get('cnName', ''),
        "fieldDataType": field.get('dataType', ''),
        "mapperRule": 5,
        "mapperRuleName": None,
        "expression": snake_to_camel(physical_name),  # 转换为驼峰形式
        "required": field.get('required', 0)
    }

def convert_fields(input_file, output_file):
    """
    转换字段数组
    """
    with open(input_file, 'r', encoding='utf-8') as f:
        input_data = json.load(f)
    
    result = []
    for field in input_data:
        converted = convert_field(field)
        if converted is not None:
            result.append(converted)
    
    # 保存结果
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    
    print(f"转换完成！共转换了 {len(result)} 个字段")
    print(f"结果已保存到: {output_file}")
    
    return result

if __name__ == '__main__':
    input_file = '.cursor/field.json'
    output_file = 'field_mapping_result.json'
    convert_fields(input_file, output_file)

