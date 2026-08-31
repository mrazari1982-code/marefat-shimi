const assert = require('assert');
const c = require('../public/curriculum-ui.js');
const rows = [
  {id:1,book_id:9,parent_id:null,node_type:'chapter',name:'فصل یک',sort_order:1},
  {id:2,book_id:9,parent_id:1,node_type:'topic',name:'مبحث الف',sort_order:1},
  {id:3,book_id:9,parent_id:2,node_type:'subtopic',name:'زیرمبحث ب',sort_order:1}
];
const index = c.indexRows(rows);
assert.deepStrictEqual(c.children(index,null,'chapter',9).map(x=>x.id),[1]);
assert.strictEqual(c.path(index,3),'فصل یک / مبحث الف / زیرمبحث ب');
assert.deepStrictEqual(c.requiredLevels('school'),['chapter']);
assert.deepStrictEqual(c.requiredLevels('konkur'),['chapter','topic','subtopic']);
assert.deepStrictEqual(c.uniqueBooks([{id:1,book_code:'A'},{id:1,book_code:'A'},{id:2,book_code:'B'}]).map(x=>x.id),[1,2]);
console.log('PASS curriculum-ui');
