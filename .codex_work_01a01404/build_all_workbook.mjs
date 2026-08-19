import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const result = JSON.parse(await fs.readFile('all_match_result.json', 'utf8'));
const outputDir = '/Users/zhangheng/database/ai_sql/outputs/01a01404-c93d-7231-8b66-0cd0a00c21f9';
const outputPath = `${outputDir}/历史错误数据.xlsx`;

const colors = {
  navy: '#1F4E78',
  blue: '#D9EAF7',
  paleBlue: '#EAF3F8',
  red: '#FCE4D6',
  gray: '#F2F2F2',
  border: '#B7C9D6',
  text: '#1F2933',
};

const workbook = Workbook.create();
const summary = workbook.worksheets.add('对比汇总');
const allDetails = workbook.worksheets.add('全部JSON明细');
const unmatched = workbook.worksheets.add('未匹配键汇总');
const matched = workbook.worksheets.add('匹配工单明细');

function lastRow(count, firstDataRow = 3) {
  return Math.max(firstDataRow, firstDataRow + count - 1);
}

function applyTitle(sheet, range, title) {
  sheet.getRange(range).merge();
  const titleCell = sheet.getRange(range.split(':')[0]);
  titleCell.values = [[title]];
  titleCell.format = {
    fill: colors.navy,
    font: { bold: true, color: '#FFFFFF', size: 16 },
    horizontalAlignment: 'left',
    verticalAlignment: 'center',
  };
  sheet.getRange(range).format.rowHeight = 28;
}

function applyHeader(range) {
  range.format = {
    fill: colors.blue,
    font: { bold: true, color: colors.text },
    horizontalAlignment: 'center',
    verticalAlignment: 'center',
    wrapText: true,
    borders: { preset: 'all', style: 'thin', color: colors.border },
  };
  range.format.rowHeight = 28;
}

function cellValue(value) {
  return value === null || value === undefined ? '' : value;
}

const detailHeaders = ['CSV行号', '入库单号', 'JSON明细序号', '匹配键', '入库物料编码', '入库批次号', '入库数量', '入库时间', '入库库位编码'];
const unmatchedHeaders = ['匹配键', '入库物料编码', '入库批次号', 'JSON明细次数', '来源入库单数', '示例入库单号', '匹配结果'];
const allDetailLastRow = lastRow(result.all_details.length);
const unmatchedLastRow = lastRow(result.unmatched_key_summary.length);

applyTitle(summary, 'A1:F1', '历史错误数据全量匹配分析');
summary.getRange('A3:B10').values = [
  ['CSV 数据行数', result.csv_row_count],
  ['全部 JSON 明细数', null],
  ['未匹配唯一键数', null],
  ['完全匹配工单行数', null],
  ['未匹配 JSON 明细数', null],
  ['JSON 解析异常行数', result.invalid_json_row_count],
  ['匹配规则', '投料物料编码 + 物料批次号，均与 CSV 第二列 JSON 的 materialCode + batchNo 完全一致'],
  ['结论', '投料表中未找到任何完全一致的物料编码和批次号组合。'],
];
summary.getRange('B4').formulas = [[`=COUNTA('全部JSON明细'!A3:A${allDetailLastRow})`]];
summary.getRange('B5').formulas = [[`=COUNTA('未匹配键汇总'!A3:A${unmatchedLastRow})`]];
summary.getRange('B6').formulas = [[`=COUNTIF('匹配工单明细'!A3:A3,\"已匹配\")`]];
summary.getRange('B7').formulas = [[`=SUM('未匹配键汇总'!D3:D${unmatchedLastRow})`]];
summary.getRange('A3:A10').format = {
  fill: colors.blue,
  font: { bold: true, color: colors.text },
  borders: { preset: 'all', style: 'thin', color: colors.border },
  verticalAlignment: 'center',
};
summary.getRange('B3:B10').format = {
  borders: { preset: 'all', style: 'thin', color: colors.border },
  verticalAlignment: 'center',
  wrapText: true,
};
summary.getRange('B6:B7').format.fill = colors.red;
summary.getRange('B10').format.fill = colors.red;
summary.getRange('A12:F12').merge();
summary.getRange('A12').values = [['来源文件']];
summary.getRange('A12').format = {
  fill: colors.paleBlue,
  font: { bold: true, color: colors.text },
  borders: { preset: 'outside', style: 'thin', color: colors.border },
};
summary.getRange('A13:B14').values = [
  ['CSV', result.source_csv],
  ['投料数据', result.source_xlsx],
];
summary.getRange('A13:A14').format = { fill: colors.gray, font: { bold: true }, borders: { preset: 'all', style: 'thin', color: colors.border } };
summary.getRange('B13:B14').format = { borders: { preset: 'all', style: 'thin', color: colors.border } };
summary.getRange('A3:A14').format.columnWidth = 24;
summary.getRange('B3:B14').format.columnWidth = 76;
summary.getRange('A3:B14').format.autofitRows();
summary.showGridLines = false;

applyTitle(allDetails, 'A1:I1', 'CSV 第二列 JSON 全部展开明细');
allDetails.getRange('A2:I2').values = [detailHeaders];
applyHeader(allDetails.getRange('A2:I2'));
allDetails.getRange(`B3:B${allDetailLastRow}`).setNumberFormat('@');
allDetails.getRange(`D3:F${allDetailLastRow}`).setNumberFormat('@');
allDetails.getRange(`I3:I${allDetailLastRow}`).setNumberFormat('@');
allDetails.getRange(`A3:I${allDetailLastRow}`).values = result.all_details.map(row => detailHeaders.map(header => cellValue(row[header])));
allDetails.getRange(`G3:G${allDetailLastRow}`).setNumberFormat('0.0000');
allDetails.getRange(`A1:A${allDetailLastRow}`).format.columnWidth = 11;
allDetails.getRange(`B1:B${allDetailLastRow}`).format.columnWidth = 20;
allDetails.getRange(`C1:C${allDetailLastRow}`).format.columnWidth = 13;
allDetails.getRange(`D1:D${allDetailLastRow}`).format.columnWidth = 30;
allDetails.getRange(`E1:E${allDetailLastRow}`).format.columnWidth = 16;
allDetails.getRange(`F1:F${allDetailLastRow}`).format.columnWidth = 23;
allDetails.getRange(`G1:G${allDetailLastRow}`).format.columnWidth = 14;
allDetails.getRange(`H1:H${allDetailLastRow}`).format.columnWidth = 25;
allDetails.getRange(`I1:I${allDetailLastRow}`).format.columnWidth = 15;
allDetails.freezePanes.freezeRows(2);
allDetails.showGridLines = false;

applyTitle(unmatched, 'A1:G1', '未匹配键汇总');
unmatched.getRange('A2:G2').values = [unmatchedHeaders];
applyHeader(unmatched.getRange('A2:G2'));
unmatched.getRange(`A3:C${unmatchedLastRow}`).setNumberFormat('@');
unmatched.getRange(`F3:F${unmatchedLastRow}`).setNumberFormat('@');
unmatched.getRange(`A3:G${unmatchedLastRow}`).values = result.unmatched_key_summary.map(row => unmatchedHeaders.map(header => cellValue(row[header])));
unmatched.getRange(`D3:E${unmatchedLastRow}`).setNumberFormat('#,##0');
unmatched.getRange(`G3:G${unmatchedLastRow}`).format = {
  fill: colors.red,
  font: { bold: true, color: '#9C0006' },
  horizontalAlignment: 'center',
};
unmatched.getRange(`A1:A${unmatchedLastRow}`).format.columnWidth = 30;
unmatched.getRange(`B1:B${unmatchedLastRow}`).format.columnWidth = 16;
unmatched.getRange(`C1:C${unmatchedLastRow}`).format.columnWidth = 23;
unmatched.getRange(`D1:E${unmatchedLastRow}`).format.columnWidth = 15;
unmatched.getRange(`F1:F${unmatchedLastRow}`).format.columnWidth = 45;
unmatched.getRange(`G1:G${unmatchedLastRow}`).format.columnWidth = 13;
unmatched.freezePanes.freezeRows(2);
unmatched.showGridLines = false;

applyTitle(matched, 'A1:D1', '完全匹配的工单投料行');
matched.getRange('A3:D3').merge();
matched.getRange('A3').values = [['未找到物料编码与批次号均一致的投料记录，因此无生产工单号可列示。']];
matched.getRange('A3').format = {
  fill: colors.red,
  font: { color: '#9C0006' },
  wrapText: true,
  verticalAlignment: 'center',
  borders: { preset: 'outside', style: 'thin', color: colors.border },
};
matched.getRange('A3:D3').format.rowHeight = 32;
matched.getRange('A1:D3').format.columnWidth = 24;
matched.showGridLines = false;

await fs.mkdir(outputDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

const check = await workbook.inspect({
  kind: 'table',
  range: '对比汇总!A1:B14',
  include: 'values,formulas',
  tableMaxRows: 14,
  tableMaxCols: 2,
});
console.log(check.ndjson);
const errors = await workbook.inspect({
  kind: 'match',
  searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A',
  options: { useRegex: true, maxResults: 100 },
  summary: 'formula error scan',
});
console.log(errors.ndjson);

for (const [sheetName, range] of [
  ['对比汇总', 'A1:F14'],
  ['全部JSON明细', 'A1:I15'],
  ['未匹配键汇总', 'A1:G15'],
  ['匹配工单明细', 'A1:D3'],
]) {
  const image = await workbook.render({ sheetName, range, scale: 1.1, format: 'png' });
  await fs.writeFile(`${outputDir}/${sheetName}.png`, new Uint8Array(await image.arrayBuffer()));
}
console.log(`OUTPUT=${outputPath}`);
