const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const html = fs.readFileSync(path.join(__dirname, '../public/exam.html'), 'utf8');
const script = html.match(/<script>\s*([\s\S]*?)<\/script>/)?.[1] || '';

test('question grouping keeps type, score, and a descriptive row with null options', () => {
  assert.match(script, /question_type/);
  assert.match(script, /option_id\s*!=\s*null/);
  assert.match(script, /type:\s*x\.question_type/);
});

test('descriptive question renders a bounded textarea and explicit save control', () => {
  assert.match(html, /textarea/);
  assert.match(html, /maxlength=["']10000["']/);
  assert.match(html, /ذخیره پاسخ تشریحی/);
  assert.match(script, /saveDescriptiveAnswer/);
  assert.match(script, /v5_save_descriptive_answer/);
});

test('saved descriptive text is restored and counted as answered', () => {
  assert.match(script, /answer_text/);
  assert.match(script, /\.value\s*=\s*String\(a\.answer_text/);
  assert.match(script, /textarea\[data-eq/);
});

test('locking and timer expiry disable both radio and descriptive controls', () => {
  assert.match(script, /input\[type=radio\],textarea,button\[data-save-descriptive\]/);
});
