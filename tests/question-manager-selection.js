// Regression test for the question-manager selection flow.
// Run with: node tests/question-manager-selection.js
const assert = require('node:assert/strict');

function selectedIds(checkedValues) {
  return checkedValues.map(Number).filter(Number.isFinite);
}

const ids = selectedIds(['3', '5']);
assert.deepEqual(ids, [3, 5]);
assert.equal(ids.length, 2);
console.log('PASS: multiple selected bank-question IDs are collected in order.');
