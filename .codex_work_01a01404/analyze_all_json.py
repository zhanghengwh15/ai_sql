import csv
import json
from collections import defaultdict
from pathlib import Path

import pandas as pd

csv_path = Path('/Users/zhangheng/database/mysql/poit_data_center_dater_inbound_finsh_data.csv')
xlsx_path = Path('/Users/zhangheng/Downloads/工单投料数据260818160156.xlsx')
output_path = Path('all_match_result.json')

all_details = []
invalid_rows = []
with csv_path.open('r', encoding='utf-8-sig', newline='') as source:
    for source_row_number, row in enumerate(csv.reader(source), start=1):
        if len(row) < 2 or not row[1].strip():
            invalid_rows.append({'CSV行号': source_row_number, '入库单号': row[0] if row else '', '原因': '第二列为空或缺失'})
            continue
        try:
            entries = json.loads(row[1])
        except json.JSONDecodeError as error:
            invalid_rows.append({'CSV行号': source_row_number, '入库单号': row[0], '原因': f'JSON 解析失败: {error.msg}'})
            continue
        if not isinstance(entries, list):
            invalid_rows.append({'CSV行号': source_row_number, '入库单号': row[0], '原因': 'JSON 不是数组'})
            continue
        for item_index, item in enumerate(entries, start=1):
            material_code = str(item.get('materialCode', '')).strip()
            batch_no = str(item.get('batchNo', '')).strip()
            all_details.append({
                'CSV行号': source_row_number,
                '入库单号': row[0],
                'JSON明细序号': item_index,
                '匹配键': f'{material_code} | {batch_no}',
                '入库物料编码': material_code,
                '入库批次号': batch_no,
                '入库数量': item.get('quantity', ''),
                '入库时间': item.get('entryTime', ''),
                '入库库位编码': str(item.get('entryStoreLocationCode', '')).strip(),
            })

materials = pd.read_excel(xlsx_path, sheet_name='工单投料数据', dtype=str, keep_default_na=False)
materials['投料物料编码'] = materials['投料物料编码'].astype(str).str.strip()
materials['物料批次号'] = materials['物料批次号'].astype(str).str.strip()

material_lookup = defaultdict(list)
for record in materials.to_dict(orient='records'):
    key = (record['投料物料编码'], record['物料批次号'])
    material_lookup[key].append(record)

compare_columns = [
    'CSV行号', '入库单号', 'JSON明细序号', '匹配键', '入库物料编码', '入库批次号',
    '入库数量', '入库时间', '入库库位编码', '生产工单号', '工单模板', '投料工厂单元',
    '投料日期', '投料班次', '投料物料编码', '投料物料名称', '投料计量单位', '投料数量',
    '退料数量', '投料状态', '单据编码', '投料时间', '投料人', '投料班组', '物料批次号',
    '出库仓库/库位', '容器', '产品物料名称', '计划产量', '产品计量单位', '产品规格描述',
    'BOM版本', '工序工艺', '供应商', '匹配结果',
]
comparison_rows = []
matched_rows = []
unmatched_rows = []
for inbound in all_details:
    matches = material_lookup.get((inbound['入库物料编码'], inbound['入库批次号']), [])
    if matches:
        for target in matches:
            row = {**inbound, **target, '匹配结果': '已匹配'}
            comparison_rows.append({column: row.get(column, '') for column in compare_columns})
            matched_rows.append({column: row.get(column, '') for column in compare_columns})
    else:
        row = {**inbound, '匹配结果': '未匹配'}
        comparison_rows.append({column: row.get(column, '') for column in compare_columns})
        unmatched_rows.append({column: row.get(column, '') for column in compare_columns})

unique_inbound_keys = {(item['入库物料编码'], item['入库批次号']) for item in all_details}
matched_inbound_keys = {key for key in unique_inbound_keys if key in material_lookup}
unmatched_key_summary = []
key_counts = defaultdict(int)
key_documents = defaultdict(list)
for item in all_details:
    key = (item['入库物料编码'], item['入库批次号'])
    if key in material_lookup:
        continue
    key_counts[key] += 1
    if item['入库单号'] not in key_documents[key]:
        key_documents[key].append(item['入库单号'])
for key in sorted(key_counts):
    documents = key_documents[key]
    unmatched_key_summary.append({
        '匹配键': f'{key[0]} | {key[1]}',
        '入库物料编码': key[0],
        '入库批次号': key[1],
        'JSON明细次数': key_counts[key],
        '来源入库单数': len(documents),
        '示例入库单号': '、'.join(documents[:5]),
        '匹配结果': '未匹配',
    })
result = {
    'source_csv': csv_path.name,
    'source_xlsx': xlsx_path.name,
    'csv_row_count': source_row_number,
    'json_detail_count': len(all_details),
    'unique_key_count': len(unique_inbound_keys),
    'matched_key_count': len(matched_inbound_keys),
    'matched_inbound_detail_count': len({(r['CSV行号'], r['JSON明细序号']) for r in matched_rows}),
    'matched_work_order_row_count': len(matched_rows),
    'matched_work_order_count': len({r['生产工单号'] for r in matched_rows}),
    'unmatched_inbound_detail_count': len(unmatched_rows),
    'invalid_json_row_count': len(invalid_rows),
    'all_details': all_details,
    'matched_rows': matched_rows,
    'unmatched_rows': unmatched_rows,
    'unmatched_key_summary': unmatched_key_summary,
    'invalid_rows': invalid_rows,
}
output_path.write_text(json.dumps(result, ensure_ascii=False), encoding='utf-8')
print(json.dumps({
    key: result[key] for key in [
        'csv_row_count', 'json_detail_count', 'unique_key_count', 'matched_key_count',
        'matched_inbound_detail_count', 'matched_work_order_row_count',
        'matched_work_order_count', 'unmatched_inbound_detail_count', 'invalid_json_row_count'
    ]
}, ensure_ascii=False, indent=2))
