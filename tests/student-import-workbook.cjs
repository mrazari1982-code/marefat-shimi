const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ExcelJS = require('../public/vendor/exceljs-4.4.0.min.js');
const source = fs.readFileSync(path.join(__dirname, '../public/student-import.js'), 'utf8');
new Function(source)();
const api = globalThis.MarefatStudentImport;

const lookups = {
  grades: [{id: 1, name: 'دهم'}],
  fields: [{id: 10, name: 'ریاضی'}],
  classes: [{id: 100, name: '۱۰۱', grade_id: 1, field_id: 10}]
};

(async () => {
  assert.equal(typeof api.buildTemplate, 'function', 'template builder must be exported');
  assert.equal(typeof api.readWorkbook, 'function', 'workbook reader must be exported');
  assert.equal(typeof api.buildCredentialWorkbook, 'function', 'result builder must be exported');

  const templateBytes = await api.buildTemplate(lookups, ExcelJS);
  const template = new ExcelJS.Workbook();
  await template.xlsx.load(templateBytes);
  assert.deepEqual(template.worksheets.map(x => x.name), ['دانش‌آموزان', 'راهنما']);
  assert.equal(template.getWorksheet('دانش‌آموزان').getCell('A2').numFmt, '@');
  assert.match(template.getWorksheet('راهنما').getCell('A1').value, /محرمانه/);

  const input = new ExcelJS.Workbook();
  const sheet = input.addWorksheet('دانش‌آموزان');
  sheet.addRow(api.HEADERS);
  sheet.getColumn(1).numFmt = '@';
  sheet.addRow(['0012', 'علی رضایی', 'دهم', 'ریاضی', '۱۰۱']);
  const parsed = await api.readWorkbook(await input.xlsx.writeBuffer(), ExcelJS);
  assert.equal(parsed.length, 1);
  assert.equal(parsed[0]['کد دانش‌آموزی'], '0012');

  sheet.getCell('A1').value = 'سرستون نادرست';
  await assert.rejects(() => api.readWorkbook(input.xlsx.writeBuffer(), ExcelJS), /ستون/);

  const outputRows = [
    {rowNumber: 2, student_code: 'NEW-1', full_name: '=HYPERLINK("bad")', password: 'Secret234ABC', grade_name: 'دهم', field_name: 'ریاضی', class_name: '۱۰۱', server_status: 'created', errors: []},
    {rowNumber: 3, student_code: 'OLD-1', full_name: 'قدیمی', password: '', grade_name: '', field_name: '', class_name: '', server_status: 'existing', errors: []},
    {rowNumber: 4, student_code: 'BAD-1', full_name: 'ناقص', password: '', grade_name: '', field_name: '', class_name: '', server_status: 'invalid', errors: ['پایه ناشناخته است.']}
  ];
  const resultBytes = await api.buildCredentialWorkbook(outputRows, ExcelJS);
  const result = new ExcelJS.Workbook();
  await result.xlsx.load(resultBytes);
  assert.deepEqual(result.worksheets.map(x => x.name), ['اطلاعات ورود', 'خطاها']);
  const credentials = result.getWorksheet('اطلاعات ورود');
  assert.equal(credentials.rowCount, 2, 'only newly created users belong in the credential sheet');
  assert.equal(credentials.getCell('C2').value, 'Secret234ABC');
  assert.match(credentials.getCell('A2').value, /^'/, 'formula-like cells must be neutralized');
  const errors = result.getWorksheet('خطاها');
  assert.equal(errors.rowCount, 3, 'existing and invalid rows belong in the error/status sheet');
  assert.equal(errors.getCell('C2').value, 'دانش‌آموز از قبل وجود دارد؛ رمز تغییر نکرد.');

  console.log('PASS: student import template, parser, credentials and formula safety');
})().catch(error => { console.error(error); process.exitCode = 1; });
