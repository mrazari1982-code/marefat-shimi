const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync(require('node:path').join(__dirname, '../public/student-import.js'), 'utf8');
const crypto = {getRandomValues(values) { for (let i = 0; i < values.length; i++) values[i] = i; return values; }};
const context = vm.createContext({globalThis: null, crypto, Uint32Array});
context.globalThis = context;
vm.runInContext(source, context);
const api = context.MarefatStudentImport;

const lookups = {
  grades: [{id: 1, name: 'دهم'}, {id: 2, name: 'یازدهم'}],
  fields: [{id: 10, name: 'ریاضی'}],
  classes: [{id: 100, name: '۱۰۱', grade_id: 1, field_id: 10}],
  existingCodes: ['OLD-1']
};

{
  const rows = api.validateRows([
    {'کد دانش‌آموزی': '0012', 'نام و نام خانوادگی': ' علی رضایی ', 'پایه': 'دهم', 'رشته': 'ریاضی', 'کلاس': '۱۰۱'},
    {'کد دانش‌آموزی': 'old-1', 'نام و نام خانوادگی': 'دانش‌آموز موجود'},
    {'کد دانش‌آموزی': '0012', 'نام و نام خانوادگی': 'کد تکراری'}
  ], lookups);
  assert.equal(rows[0].student_code, '0012', 'leading zero must remain part of the username');
  assert.equal(rows[0].full_name, 'علی رضایی');
  assert.equal(rows[0].status, 'invalid', 'both copies of an in-file duplicate must be invalid');
  assert.equal(rows[1].status, 'existing', 'database duplicates must be skipped');
  assert.equal(rows[2].status, 'invalid');
  assert.match(rows[2].errors.join(' '), /تکراری/);
}

{
  const [row] = api.validateRows([
    {'کد دانش‌آموزی': 'S-2', 'نام و نام خانوادگی': 'نمونه', 'پایه': 'یازدهم', 'رشته': 'ریاضی', 'کلاس': '۱۰۱'}
  ], lookups);
  assert.equal(row.status, 'invalid', 'class must belong to the selected grade and field');
  assert.match(row.errors.join(' '), /سازگار/);
}

{
  const [row] = api.validateRows([
    {'کد دانش‌آموزی': 'S-3', 'نام و نام خانوادگی': 'نمونه', 'پایه': 'ناشناخته'}
  ], lookups);
  assert.equal(row.status, 'invalid');
  assert.match(row.errors.join(' '), /پایه/);
}

{
  const password = api.generatePassword();
  assert.equal(password.length, 12);
  assert.match(password, /^[A-HJ-NP-Za-km-z2-9]+$/);
  assert.doesNotMatch(password, /[0OIl1]/);
}

{
  const input = [
    {student_code: 'NEW-1', full_name: 'جدید', password: 'SecretOne23', status: 'valid', errors: []},
    {student_code: 'OLD-1', full_name: 'موجود', password: 'MustDisappear9', status: 'existing', errors: []}
  ];
  const output = api.credentialRows(input, [
    {student_code: 'NEW-1', status: 'created', student_id: 51},
    {student_code: 'OLD-1', status: 'existing', student_id: 1}
  ]);
  assert.equal(output[0].password, 'SecretOne23');
  assert.equal(output[1].password, '', 'existing accounts must never receive a generated password');
}

console.log('PASS: student import normalization, duplicates, lookups, passwords and credential filtering');
