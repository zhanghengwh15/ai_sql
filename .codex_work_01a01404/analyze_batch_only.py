import csv
import json
from collections import Counter

import pandas as pd

csv_path = '/Users/zhangheng/database/mysql/poit_data_center_dater_inbound_finsh_data.csv'
xlsx_path = '/Users/zhangheng/Downloads/工单投料数据260818160156.xlsx'

source_batches = Counter()
csv_rows = 0
invalid_json_rows = 0
with open(csv_path, encoding='utf-8-sig', newline='') as source:
    for row in csv.reader(source):
        csv_rows += 1
        try:
            entries = json.loads(row[1])
            source_batches.update(str(entry.get('batchNo', '')).strip() for entry in entries)
        except (IndexError, json.JSONDecodeError, TypeError):
            invalid_json_rows += 1

materials = pd.read_excel(xlsx_path, sheet_name='工单投料数据', dtype=str, keep_default_na=False)
target_batches = Counter(materials['物料批次号'].astype(str).str.strip())
source_batch_set = set(source_batches) - {''}
target_batch_set = set(target_batches) - {''}
matched_batches = sorted(source_batch_set & target_batch_set)

print({
    'csv_rows': csv_rows,
    'json_detail_count': sum(source_batches.values()),
    'json_unique_batch_count': len(source_batch_set),
    'work_order_rows': len(materials),
    'work_order_unique_batch_count': len(target_batch_set),
    'matched_unique_batch_count': len(matched_batches),
    'matched_json_detail_count': sum(source_batches[batch] for batch in matched_batches),
    'matched_work_order_row_count': sum(target_batches[batch] for batch in matched_batches),
    'batch_only_join_row_count': sum(source_batches[batch] * target_batches[batch] for batch in matched_batches),
    'sample_matched_batches': matched_batches[:20],
    'invalid_json_rows': invalid_json_rows,
})
