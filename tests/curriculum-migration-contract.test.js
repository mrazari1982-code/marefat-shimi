const assert=require('assert'),fs=require('fs'),path=require('path');
const sql=fs.readFileSync(path.join(__dirname,'../supabase/migrations/20260831160000_v5_admin_curriculum_ui.sql'),'utf8');
assert.ok(sql.includes('q.bank_question_id is null'),'bank listing must exclude exam snapshots');
assert.ok(sql.includes('returning id into snapshot_id'),'exam builder must create a question snapshot');
assert.ok(sql.includes('select snapshot_id,option_key,option_text,is_correct'),'exam builder must snapshot options');
assert.ok(sql.includes('revoke all on function public.v5_admin_save_curriculum_question'),'anonymous execution must be revoked');
console.log('PASS curriculum migration snapshot and permissions');
