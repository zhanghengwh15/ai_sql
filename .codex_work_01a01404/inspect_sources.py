import csv
import json
from pathlib import Path

import pandas as pd

csv_path = Path('/Users/zhangheng/database/mysql/poit_data_center_dater_inbound_finsh_data.csv')
xlsx_path = Path('/Users/zhangheng/Downloads/工单投料数据260818160156.xlsx')

with csv_path.open('r', encoding='utf-8-sig', newline='') as source:
    rows = list(csv.reader(source))

record_id, payload = rows[1]
details = json.loads(payload)

workbook = pd.ExcelFile(xlsx_path)
result = {
    'csv_second_record_id': record_id,
    'csv_second_details': details,
    'sheets': {},
}
for sheet_name in workbook.sheet_names:
    frame = pd.read_excel(xlsx_path, sheet_name=sheet_name, dtype=str, keep_default_na=False)
    result['sheets'][sheet_name] = {
        'row_count': len(frame),
        'columns': frame.columns.tolist(),
        'sample': frame.head(5).to_dict(orient='records'),
    }

print(json.dumps(result, ensure_ascii=False, indent=2))
