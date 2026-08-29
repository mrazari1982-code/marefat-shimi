const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const ExcelJS = require('../public/vendor/exceljs-4.4.0.min.js');
const source = fs.readFileSync(path.join(__dirname, '../public/student-import.js'), 'utf8');
new Function(source)();
const api = globalThis.MarefatStudentImport;

const lookups = {
  grades: [{id: 1, name: 'دهم'}, {id: 2, name: '-بدون پایه'}],
  fields: [{id: 10, name: 'ریاضی'}, {id: 11, name: '+عمومی'}],
  classes: [{id: 100, name: '۱۰۱', grade_id: 1, field_id: 10}]
};

(async () => {
  assert.equal(typeof api.buildTemplate, 'function', 'template builder must be exported');
  assert.equal(typeof api.readWorkbook, 'function', 'workbook reader must be exported');
  assert.equal(typeof api.buildCredentialWorkbook, 'function', 'result builder must be exported');

  const templateBytes = await api.buildTemplate(lookups, ExcelJS);
  const template = new ExcelJS.Workbook();
  await template.xlsx.load(templateBytes);
  assert.deepEqual(template.worksheets.map(x => x.name), ['دانش‌آموزان', 'راهنما', 'فهرست‌ها']);
  const studentSheet = template.getWorksheet('دانش‌آموزان');
  assert.equal(studentSheet.getCell('A2').numFmt, '@');
  assert.deepEqual(studentSheet.getCell('C2').dataValidation, {
    type: 'list', allowBlank: true, formulae: ["'فهرست‌ها'!$A$2:$A$3"]
  }, 'grade must be selected from the active grade list');
  assert.deepEqual(studentSheet.getCell('D2').dataValidation, {
    type: 'list', allowBlank: true, formulae: ["'فهرست‌ها'!$B$2:$B$3"]
  }, 'field must be selected from the active field list');
  assert.deepEqual(studentSheet.getCell('C501').dataValidation, studentSheet.getCell('C2').dataValidation,
    'dropdowns must cover all 500 allowed data rows');
  const lists = template.getWorksheet('فهرست‌ها');
  assert.equal(lists.state, 'veryHidden');
  assert.equal(lists.getCell('A2').value, 'دهم');
  assert.equal(lists.getCell('B2').value, 'ریاضی');
  assert.equal(lists.getCell('A3').value, '-بدون پایه', 'lookup names must remain exact text');
  assert.equal(lists.getCell('B3').value, '+عمومی', 'formula-like lookup names must remain exact text');
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
