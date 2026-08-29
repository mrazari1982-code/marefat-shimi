const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const pagePath = path.join(__dirname, '../public/admin-student-import.html');
assert.ok(fs.existsSync(pagePath), 'bulk import page must exist');
const html = fs.readFileSync(pagePath, 'utf8');

assert.match(html, /vendor\/exceljs-4\.4\.0\.min\.js/);
assert.match(html, /student-import\.js/);
assert.match(html, /v5_admin_student_import_context/);
assert.match(html, /v5_admin_import_students/);
assert.match(html, /getUser\(\)/, 'page must verify the current user');
assert.match(html, /\['admin','deputy'\]\.includes/, 'page must enforce the staff roles in the UI');
assert.match(html, /2\s*\*\s*1024\s*\*\s*1024/, 'page must cap files at 2 MiB');
assert.match(html, /\.xlsx/);
assert.doesNotMatch(html, /innerHTML\s*=/, 'untrusted spreadsheet content must not reach innerHTML');
assert.match(html, /row\.password\s*=\s*''/, 'plaintext passwords must be cleared after export');
assert.match(html, /candidates\.forEach\(row=>\{row\.password=''\}\)/,
  'source rows holding generated passwords must also be cleared');
assert.match(html, /rows\.filter\(row=>row\.status==='valid'&&!row\.server_status\)/,
  'known existing accounts must not receive or transmit a temporary password');

console.log('PASS: student import page security and integration wiring');
