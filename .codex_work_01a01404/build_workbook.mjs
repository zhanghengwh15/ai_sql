import fs from 'node:fs/promises';
import { SpreadsheetFile, Workbook } from '@oai/artifact-tool';

const result = JSON.parse(await fs.readFile('match_result.json', 'utf8'));
const outputDir = '/Users/zhangheng/database/ai_sql/outputs/01a01404-c93d-7231-8b66-0cd0a00c21f9';
const outputPath = `${outputDir}/历史错误数据.xlsx`;

const colors = {
  navy: '#1F4E78',
  blue: '#D9EAF7',
  paleBlue: '#EAF3F8',
  green: '#E2F0D9',
  red: '#FCE4D6',
  gray: '#F2F2F2',
  border: '#B7C9D6',
  text: '#1F2933',
};

const workbook = Workbook.create();
const summary = workbook.worksheets.add('对比汇总');
const comparison = workbook.worksheets.add('对比结果');
const source = workbook.worksheets.add('CSV第二行明细');
const matched = workbook.worksheets.add('匹配工单明细');

function applyTitle(sheet, range, title) {
  sheet.getRange(range).merge();
  const cell = sheet.getRange(range.split(':')[0]);
  cell.values = [[title]];
  cell.format = {
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
}

function applyData(range) {
  range.format = {
    verticalAlignment: 'center',
    wrapText: true,
    borders: { preset: 'inside', style: 'thin', color: '#D9E2F3' },
  };
}

function displayValue(header, value) {
  if (value === null || value === undefined || value === '') return '';
  return value;
}

applyTitle(summary, 'A1:F1', '历史错误数据匹配分析');
summary.getRange('A3:B8').values = [
  ['入库单号', result.inbound_record_id],
  ['匹配规则', '投料物料编码 + 物料批次号，均与 CSV 第二行 JSON 的 materialCode + batchNo 完全一致'],
  ['CSV 第二行明细数', null],
  ['完全匹配投料行数', null],
  ['未匹配明细数', null],
  ['结论', '未找到物料编码与批次号均一致的投料记录，生产工单号为空。'],
];
summary.getRange('B5').formulas = [["=COUNTA('CSV第二行明细'!A3:A6)"]];
summary.getRange('B6').formulas = [["=COUNTIF('对比结果'!AD3:AD6,\"已匹配\")"]];
summary.getRange('B7').formulas = [["=COUNTIF('对比结果'!AD3:AD6,\"未匹配\")"]];
summary.getRange('A3:A8').format = {
  fill: colors.blue,
  font: { bold: true, color: colors.text },
  borders: { preset: 'all', style: 'thin', color: colors.border },
  verticalAlignment: 'center',
};
summary.getRange('B3:B8').format = {
  borders: { preset: 'all', style: 'thin', color: colors.border },
  verticalAlignment: 'center',
  wrapText: true,
};
summary.getRange('B6:B7').format.fill = colors.red;
summary.getRange('B8').format.fill = colors.red;
summary.getRange('A10:F10').merge();
summary.getRange('A10').values = [['来源文件']];
summary.getRange('A10').format = {
  fill: colors.paleBlue,
  font: { bold: true, color: colors.text },
  borders: { preset: 'outside', style: 'thin', color: colors.border },
};
summary.getRange('A11:B12').values = [
  ['CSV', result.source_csv],
  ['投料数据', result.source_xlsx],
];
summary.getRange('A11:A12').format = { fill: colors.gray, font: { bold: true }, borders: { preset: 'all', style: 'thin', color: colors.border } };
summary.getRange('B11:B12').format = { borders: { preset: 'all', style: 'thin', color: colors.border } };
summary.getRange('A3:A12').format.columnWidth = 22;
summary.getRange('B3:B12').format.columnWidth = 72;
summary.getRange('A3:B12').format.autofitRows();
summary.showGridLines = false;

const detailHeaders = ['匹配键', '入库物料编码', '入库批次号', '入库数量', '入库时间', '入库库位编码'];
applyTitle(source, 'A1:F1', 'CSV 第二行 JSON 入库明细');
source.getRange('A2:F2').values = [detailHeaders];
applyHeader(source.getRange('A2:F2'));
source.getRange('B3:C6').setNumberFormat('@');
source.getRange('A3:F6').values = result.inbound_details.map(item => detailHeaders.map(header => displayValue(header, item[header])));
applyData(source.getRange('A3:F6'));
source.getRange('D3:D6').format.numberFormat = '0.0000';
source.getRange('A2:F6').format.autofitColumns();
source.getRange('A1:A6').format.columnWidth = 30;
source.getRange('B1:B6').format.columnWidth = 16;
source.getRange('C1:C6').format.columnWidth = 28;
source.getRange('D1:D6').format.columnWidth = 13;
source.getRange('E1:E6').format.columnWidth = 22;
source.freezePanes.freezeRows(2);
source.showGridLines = false;

const compareHeaders = [
  '匹配键', '入库物料编码', '入库批次号', '入库数量', '入库时间', '入库库位编码',
  '生产工单号', '工单模板', '投料工厂单元', '投料日期', '投料班次',
  '投料物料编码', '投料物料名称', '投料计量单位', '投料数量', '退料数量',
  '投料状态', '单据编码', '投料时间', '投料人', '物料批次号', '出库仓库/库位',
  '产品物料名称', '计划产量', '产品计量单位', '产品规格描述', 'BOM版本',
  '工序工艺', '供应商', '匹配结果',
];
applyTitle(comparison, 'A1:AD1', '按物料编码 + 批次号的逐行对比结果');
comparison.getRange('A2:AD2').values = [compareHeaders];
applyHeader(comparison.getRange('A2:AD2'));
comparison.getRange('B3:C6').setNumberFormat('@');
comparison.getRange('A3:AD6').values = result.unmatched_rows.map(item => compareHeaders.map(header => displayValue(header, item[header])));
applyData(comparison.getRange('A3:AD6'));
comparison.getRange('AD3:AD6').format = {
  fill: colors.red,
  font: { bold: true, color: '#9C0006' },
  horizontalAlignment: 'center',
  borders: { preset: 'all', style: 'thin', color: colors.border },
};
comparison.getRange('D3:D6').format.numberFormat = '0.0000';
comparison.getRange('A2:AD6').format.autofitColumns();
comparison.getRange('A1:A6').format.columnWidth = 29;
comparison.getRange('B1:B6').format.columnWidth = 16;
comparison.getRange('C1:C6').format.columnWidth = 28;
comparison.getRange('D1:D6').format.columnWidth = 13;
comparison.getRange('E1:E6').format.columnWidth = 21;
comparison.getRange('M1:M6').format.columnWidth = 24;
comparison.getRange('R1:R6').format.columnWidth = 21;
comparison.getRange('V1:V6').format.columnWidth = 28;
comparison.getRange('W1:W6').format.columnWidth = 26;
comparison.freezePanes.freezeRows(2);
comparison.showGridLines = false;

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
matched.getRange('A1:D3').format.columnWidth = 22;
matched.showGridLines = false;

await fs.mkdir(outputDir, { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);

const inspection = await workbook.inspect({
  kind: 'table',
  range: '对比汇总!A1:B12',
  include: 'values,formulas',
  tableMaxRows: 12,
  tableMaxCols: 2,
});
console.log(inspection.ndjson);
const formulaErrors = await workbook.inspect({
  kind: 'match',
  searchTerm: '#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A',
  options: { useRegex: true, maxResults: 100 },
  summary: 'formula error scan',
});
console.log(formulaErrors.ndjson);

for (const [sheetName, range] of [
  ['对比汇总', 'A1:F12'],
  ['对比结果', 'A1:AD6'],
  ['CSV第二行明细', 'A1:F6'],
  ['匹配工单明细', 'A1:D3'],
]) {
  const image = await workbook.render({ sheetName, range, scale: 1.25, format: 'png' });
  await fs.writeFile(`${outputDir}/${sheetName}.png`, new Uint8Array(await image.arrayBuffer()));
}

console.log(`OUTPUT=${outputPath}`);
