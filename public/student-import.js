(function (global) {
  'use strict';

  const HEADERS = ['کد دانش‌آموزی', 'نام و نام خانوادگی', 'پایه', 'رشته', 'کلاس'];
  const PASSWORD_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  const clean = value => String(value ?? '').trim();
  const lookupKey = value => clean(value).toLocaleLowerCase('fa');

  function cellText(cell) {
    if (!cell) return '';
    if (cell.text !== undefined) return clean(cell.text);
    const value = cell.value;
    if (value && typeof value === 'object') {
      if (Array.isArray(value.richText)) return clean(value.richText.map(part => part.text).join(''));
      if ('result' in value) return clean(value.result);
    }
    return clean(value);
  }

  function safeExcelText(value) {
    const text = clean(value);
    return /^[=+\-@]/.test(text) ? `'${text}` : text;
  }

  function styleSheet(sheet, widths) {
    sheet.views = [{rightToLeft: true, state: 'frozen', ySplit: 1}];
    sheet.autoFilter = {from: {row: 1, column: 1}, to: {row: 1, column: widths.length}};
    sheet.columns.forEach((column, index) => { column.width = widths[index] || 18; });
    const header = sheet.getRow(1);
    header.font = {bold: true, color: {argb: 'FFFFFFFF'}};
    header.fill = {type: 'pattern', pattern: 'solid', fgColor: {argb: 'FF3157D5'}};
    header.alignment = {horizontal: 'center', vertical: 'middle'};
  }

  function generatePassword(randomSource) {
    const values = new Uint32Array(12);
    (randomSource || global.crypto.getRandomValues.bind(global.crypto))(values);
    return Array.from(values, value => PASSWORD_ALPHABET[value % PASSWORD_ALPHABET.length]).join('');
  }

  function validateRows(rows, context) {
    const existing = new Set((context.existingCodes || []).map(lookupKey));
    const gradeByName = new Map((context.grades || []).map(item => [lookupKey(item.name), item]));
    const fieldByName = new Map((context.fields || []).map(item => [lookupKey(item.name), item]));
    const classByName = new Map((context.classes || []).map(item => [lookupKey(item.name), item]));

    const normalized = rows.map((raw, index) => {
      const studentCode = clean(raw[HEADERS[0]]);
      const fullName = clean(raw[HEADERS[1]]);
      const gradeName = clean(raw[HEADERS[2]]);
      const fieldName = clean(raw[HEADERS[3]]);
      const className = clean(raw[HEADERS[4]]);
      const grade = gradeByName.get(lookupKey(gradeName));
      const field = fieldByName.get(lookupKey(fieldName));
      const studentClass = classByName.get(lookupKey(className));
      const errors = [];

      if (!studentCode) errors.push('کد دانش‌آموزی الزامی است.');
      if (!fullName) errors.push('نام و نام خانوادگی الزامی است.');
      if (gradeName && !grade) errors.push('پایه ناشناخته است.');
      if (fieldName && !field) errors.push('رشته ناشناخته است.');
      if (className && !studentClass) errors.push('کلاس ناشناخته است.');
      if (studentClass && (
        (grade && Number(studentClass.grade_id) !== Number(grade.id)) ||
        (field && Number(studentClass.field_id) !== Number(field.id))
      )) errors.push('کلاس با پایه یا رشته سازگار نیست.');

      return {
        rowNumber: index + 2,
        student_code: studentCode,
        full_name: fullName,
        grade_id: grade ? Number(grade.id) : null,
        field_id: field ? Number(field.id) : null,
        class_id: studentClass ? Number(studentClass.id) : null,
        grade_name: grade ? clean(grade.name) : '',
        field_name: field ? clean(field.name) : '',
        class_name: studentClass ? clean(studentClass.name) : '',
        status: errors.length ? 'invalid' : existing.has(lookupKey(studentCode)) ? 'existing' : 'valid',
        errors
      };
    });

    const firstByCode = new Map();
    normalized.forEach((row, index) => {
      const code = lookupKey(row.student_code);
      if (!code) return;
      if (!firstByCode.has(code)) {
        firstByCode.set(code, index);
        return;
      }
      const duplicateMessage = 'کد دانش‌آموزی داخل فایل تکراری است.';
      row.status = 'invalid';
      if (!row.errors.includes(duplicateMessage)) row.errors.push(duplicateMessage);
      const first = normalized[firstByCode.get(code)];
      first.status = 'invalid';
      if (!first.errors.includes(duplicateMessage)) first.errors.push(duplicateMessage);
    });

    return normalized;
  }

  function credentialRows(rows, results) {
    const resultByCode = new Map((results || []).map(item => [lookupKey(item.student_code), item]));
    return rows.map(row => {
      const result = resultByCode.get(lookupKey(row.student_code));
      return {
        ...row,
        password: result && result.status === 'created' ? row.password : '',
        server_status: result ? result.status : row.status
      };
    });
  }

  async function readWorkbook(bytes, ExcelJS) {
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(await Promise.resolve(bytes));
    const sheet = workbook.getWorksheet('دانش‌آموزان') || workbook.worksheets[0];
    if (!sheet) throw new Error('فایل Excel هیچ برگه‌ای ندارد.');
    const actualHeaders = HEADERS.map((_, index) => cellText(sheet.getCell(1, index + 1)));
    if (actualHeaders.some((header, index) => header !== HEADERS[index])) {
      throw new Error('نام یا ترتیب ستون‌های فایل با قالب استاندارد سازگار نیست.');
    }
    const rows = [];
    for (let rowNumber = 2; rowNumber <= sheet.rowCount; rowNumber += 1) {
      const raw = {};
      HEADERS.forEach((header, index) => { raw[header] = cellText(sheet.getCell(rowNumber, index + 1)); });
      if (Object.values(raw).some(Boolean)) rows.push(raw);
    }
    if (rows.length > 500) throw new Error('حداکثر ۵۰۰ دانش‌آموز در هر فایل مجاز است.');
    return rows;
  }

  async function buildTemplate(context, ExcelJS) {
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'سامانه آزمون معرفت';
    const students = workbook.addWorksheet('دانش‌آموزان', {views: [{rightToLeft: true}]});
    students.addRow(HEADERS);
    students.getColumn(1).numFmt = '@';
    for (let row = 2; row <= 501; row += 1) students.getCell(row, 1).numFmt = '@';
    styleSheet(students, [22, 30, 16, 18, 18]);

    const guide = workbook.addWorksheet('راهنما', {views: [{rightToLeft: true}]});
    guide.addRow(['این فایل و فایل رمزهای خروجی محرمانه‌اند؛ فقط از مسیر امن در اختیار دانش‌آموز قرار دهید.']);
    guide.addRow(['دو ستون کد دانش‌آموزی و نام و نام خانوادگی الزامی است.']);
    guide.addRow(['پایه‌های فعال', ...(context.grades || []).map(item => safeExcelText(item.name))]);
    guide.addRow(['رشته‌های فعال', ...(context.fields || []).map(item => safeExcelText(item.name))]);
    guide.addRow(['کلاس‌های فعال', ...(context.classes || []).map(item => safeExcelText(item.name))]);
    guide.getColumn(1).width = 86;
    guide.views = [{rightToLeft: true}];
    return workbook.xlsx.writeBuffer();
  }

  async function buildCredentialWorkbook(rows, ExcelJS) {
    const workbook = new ExcelJS.Workbook();
    workbook.creator = 'سامانه آزمون معرفت';
    const credentials = workbook.addWorksheet('اطلاعات ورود', {views: [{rightToLeft: true}]});
    credentials.addRow(['نام و نام خانوادگی', 'نام کاربری', 'رمز عبور', 'پایه', 'رشته', 'کلاس', 'وضعیت']);
    rows.filter(row => row.server_status === 'created').forEach(row => credentials.addRow([
      safeExcelText(row.full_name), safeExcelText(row.student_code), safeExcelText(row.password),
      safeExcelText(row.grade_name), safeExcelText(row.field_name), safeExcelText(row.class_name), 'ایجاد شد'
    ]));
    credentials.getColumn(2).numFmt = '@';
    styleSheet(credentials, [30, 22, 22, 16, 18, 18, 16]);

    const errors = workbook.addWorksheet('خطاها', {views: [{rightToLeft: true}]});
    errors.addRow(['ردیف فایل', 'کد دانش‌آموزی', 'نتیجه / علت']);
    rows.filter(row => row.server_status !== 'created').forEach(row => {
      const reason = row.server_status === 'existing'
        ? 'دانش‌آموز از قبل وجود دارد؛ رمز تغییر نکرد.'
        : (row.errors || []).join(' ' ) || 'ردیف وارد نشد.';
      errors.addRow([row.rowNumber, safeExcelText(row.student_code), safeExcelText(reason)]);
    });
    errors.getColumn(2).numFmt = '@';
    styleSheet(errors, [14, 22, 64]);
    return workbook.xlsx.writeBuffer();
  }

  function downloadBlob(bytes, filename) {
    const blob = new Blob([bytes], {type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'});
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement('a');
    anchor.href = url;
    anchor.download = filename;
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  global.MarefatStudentImport = {
    HEADERS, validateRows, generatePassword, credentialRows,
    readWorkbook, buildTemplate, buildCredentialWorkbook, downloadBlob
  };
})(globalThis);
