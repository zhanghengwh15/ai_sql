import csv
import json
from pathlib import Path

import pandas as pd

csv_path = Path('/Users/zhangheng/database/mysql/poit_data_center_dater_inbound_finsh_data.csv')
xlsx_path = Path('/Users/zhangheng/Downloads/工单投料数据260818160156.xlsx')
output_path = Path('match_result.json')

with csv_path.open('r', encoding='utf-8-sig', newline='') as source:
    csv_rows = list(csv.reader(source))

inbound_record_id, payload = csv_rows[1]
inbound_details = json.loads(payload)
inbound = pd.DataFrame(inbound_details)
inbound = inbound.rename(columns={
    'materialCode': '入库物料编码',
    'batchNo': '入库批次号',
    'quantity': '入库数量',
    'entryTime': '入库时间',
    'entryStoreLocationCode': '入库库位编码',
})
inbound['入库物料编码'] = inbound['入库物料编码'].astype(str)
inbound['入库批次号'] = inbound['入库批次号'].astype(str)
inbound['匹配键'] = inbound['入库物料编码'] + ' | ' + inbound['入库批次号']

materials = pd.read_excel(xlsx_path, sheet_name='工单投料数据', dtype=str, keep_default_na=False)
materials['投料物料编码'] = materials['投料物料编码'].astype(str).str.strip()
materials['物料批次号'] = materials['物料批次号'].astype(str).str.strip()
materials['匹配键'] = materials['投料物料编码'] + ' | ' + materials['物料批次号']

matched = inbound.merge(
    materials,
    how='left',
    left_on=['入库物料编码', '入库批次号'],
    right_on=['投料物料编码', '物料批次号'],
    suffixes=('', '_投料'),
)
matched['匹配结果'] = matched['生产工单号'].map(lambda value: '已匹配' if pd.notna(value) and value != '' else '未匹配')

matched_columns = [
    '匹配键', '入库物料编码', '入库批次号', '入库数量', '入库时间', '入库库位编码',
    '生产工单号', '工单模板', '投料工厂单元', '投料日期', '投料班次',
    '投料物料编码', '投料物料名称', '投料计量单位', '投料数量', '退料数量',
    '投料状态', '单据编码', '投料时间', '投料人', '物料批次号', '出库仓库/库位',
    '产品物料名称', '计划产量', '产品计量单位', '产品规格描述', 'BOM版本',
    '工序工艺', '供应商', '匹配结果',
]
matched = matched[matched_columns].fillna('')

matched_rows = matched[matched['匹配结果'] == '已匹配'].copy()
unmatched_rows = matched[matched['匹配结果'] == '未匹配'].copy()

result = {
    'inbound_record_id': inbound_record_id,
    'source_csv': csv_path.name,
    'source_xlsx': xlsx_path.name,
    'source_detail_count': int(len(inbound)),
    'matched_key_count': int(inbound['匹配键'].isin(materials['匹配键']).sum()),
    'matched_row_count': int(len(matched_rows)),
    'matched_work_order_count': int(matched_rows['生产工单号'].nunique()),
    'unmatched_key_count': int(unmatched_rows['匹配键'].nunique()),
    'inbound_details': inbound[[
        '匹配键', '入库物料编码', '入库批次号', '入库数量', '入库时间', '入库库位编码'
    ]].fillna('').to_dict(orient='records'),
    'matched_rows': matched_rows.to_dict(orient='records'),
    'unmatched_rows': unmatched_rows.to_dict(orient='records'),
}
output_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps({
    key: result[key] for key in [
        'inbound_record_id', 'source_detail_count', 'matched_key_count', 'matched_row_count',
        'matched_work_order_count', 'unmatched_key_count'
    ]
}, ensure_ascii=False, indent=2))
