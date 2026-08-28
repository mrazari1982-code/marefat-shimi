const test = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');
const path = require('node:path');

// Execute the actual inline page code; only DOM and the external RPC boundary are doubled.
function page(file, rpc, search = '') {
  const nodes = new Map();
  const get = id => {
    if (!nodes.has(id)) nodes.set(id, {value:'', dataset:{}, disabled:false, hidden:false,
      textContent:'', innerHTML:'', className:'', addEventListener(){},
      classList:{add(){},remove(){}}});
    return nodes.get(id);
  };
  const client = {rpc,auth:{getSession:async()=>({data:{session:null}})}};
  const intervals=new Map();let timerNumber=0;
  const radios=[{disabled:false}];
  const context = vm.createContext({URL,URLSearchParams,console,Map,Set,Promise,Date:class extends Date {static now(){return Date.now()}},
    supabase:{createClient:()=>client}, window:{supabase:{createClient:()=>client}},
    location:{origin:'https://example.test',pathname:'/school/'+file,search,href:''},
    document:{getElementById:get,querySelector:()=>null,querySelectorAll:s=>s==='input[type=radio]'?radios:[]},
    confirm:()=>true,setInterval:fn=>{intervals.set(++timerNumber,fn);return timerNumber},
    clearInterval:id=>intervals.delete(id),setTimeout,clearTimeout});
  const html=fs.readFileSync(path.join(__dirname,'..',file),'utf8');
  const scripts=[...html.matchAll(/<script\b[^>]*>([\s\S]*?)<\/script>/gi)].map(x=>x[1]).join('\n');
  vm.runInContext(scripts,context);
  return {run:code=>vm.runInContext(code,context),get,context,intervals,radios};
}
const tick=()=>new Promise(resolve=>setImmediate(resolve));
test('submit waits for the selected answer to finish saving',async()=>{
  let finishSave;const calls=[];
  const p=page('exam.html',async name=>{calls.push(name);if(name==='v5_save_answer')return new Promise(r=>finishSave=()=>r({data:{saved:true,status:'started'}}));return {data:{status:'submitted',show_result:false}};});
  p.run("attempt={attempt_id:'test'}");
  const save=p.run("saveAnswer({dataset:{eq:'1'},value:'2'})");
  await tick(); const submit=p.run('submitExam(false)');await tick();
  assert.deepEqual(calls,['v5_save_answer']);
  finishSave();await save;await submit;
  assert.deepEqual(calls,['v5_save_answer','v5_submit_attempt']);
});
test('failed answer prevents manual final submission',async()=>{
  const calls=[];const p=page('exam.html',async name=>{calls.push(name);return name==='v5_save_answer'?{error:{message:'offline'}}:{data:{status:'submitted'}};});
  p.run("attempt={attempt_id:'test'}");await p.run("saveAnswer({dataset:{eq:'1'},value:'2'})");await p.run('submitExam(false)');
  assert.deepEqual(calls,['v5_save_answer']);assert.equal(p.get('submit').disabled,false);
});
test('rapid changes save in selection order',async()=>{
  const pending=[];const values=[];
  const p=page('exam.html',(name,args)=>{values.push(args.p_selected_option_id);return new Promise(r=>pending.push(()=>r({data:{saved:true,status:'started'}})));});
  p.run("attempt={attempt_id:'test'}");const a=p.run("saveAnswer({dataset:{eq:'1'},value:'2'})");const b=p.run("saveAnswer({dataset:{eq:'1'},value:'3'})");await tick();
  assert.deepEqual(values,[2]);pending.shift()();await tick();assert.deepEqual(values,[2,3]);pending.shift()();await Promise.all([a,b]);
});
test('canonical student code returned by start is used for subsequent requests',async()=>{
  const codes=[];const p=page('exam.html',async(name,args)=>{
    if(name==='v5_start_exam')return {data:{attempt_id:'test',status:'started',student_code:'TEST-ONE'}};
    codes.push(args.p_student_code);return {data:[]};
  },'?token=test&student_code=test-one');await tick();assert.deepEqual(codes,['TEST-ONE','TEST-ONE']);
});
test('publishing links preserves a subdirectory deployment',async()=>{
  const p=page('admin-exam-publish.html',async()=>({data:[]}));await tick();
  assert.equal(p.run("makeUrl('a b')"),'https://example.test/school/index.html?token=a%20b');
});
test('analytics uses attempt totals rather than averaging student averages',async()=>{
  const p=page('admin-analytics.html',async()=>({data:{
    summary:{submitted_attempts:3,average_percentage:66.67},
    students:[{average_percentage:100},{average_percentage:50}],
    exams:[{highest_percentage:100,lowest_percentage:0}],question_stats:[]
  }}));await tick();await p.run('load()');
  assert.equal(p.get('n').textContent,3);assert.equal(p.get('avg').textContent,'66.67%');
  assert.equal(p.get('min').textContent,'0.00%');
});
test('server deadline finalizes even without a duration and locks answers immediately',async()=>{
  const calls=[];let finish;
  const p=page('exam.html',name=>{calls.push(name);return new Promise(r=>finish=()=>r({data:{status:'submitted',show_result:false}}))});
  p.run("attempt={attempt_id:'test'}; startTimer({duration_minutes:null,deadline_at:new Date(Date.now()-1000).toISOString(),server_now:new Date().toISOString()})");
  await tick();assert.deepEqual(calls,['v5_submit_attempt']);assert.equal(p.radios[0].disabled,true);
  finish();await tick();assert.equal(p.intervals.size,0);
});
test('automatic submit retries after a network error while answers remain locked',async()=>{
  let calls=0;const p=page('exam.html',async()=>++calls===1?{error:{message:'offline'}}:{data:{status:'submitted',show_result:false}});
  p.run("attempt={attempt_id:'test'}; startTimer({duration_minutes:1,started_at:new Date(Date.now()-120000).toISOString()})");await tick();
  assert.equal(p.radios[0].disabled,true);assert.equal(p.intervals.size,1);
  p.run('const testNow=Date.now();Date.now=()=>testNow+5001');
  for(const fn of [...p.intervals.values()])fn();await tick();
  assert.equal(calls,2);assert.equal(p.intervals.size,0);assert.equal(p.get('result').hidden,false);
});
test('a late-save response with submitted status retrieves the final result',async()=>{
  const calls=[];const p=page('exam.html',async name=>{calls.push(name);return name==='v5_save_answer'?{data:{saved:false,status:'submitted'}}:{data:{status:'submitted',show_result:true,percentage:100,correct_answers:1}}});
  p.run("attempt={attempt_id:'test'}");await p.run("saveAnswer({dataset:{eq:'1'},value:'2'})");await tick();
  assert.deepEqual(calls,['v5_save_answer','v5_submit_attempt']);assert.match(p.get('resultText').innerHTML,/100\.00/);
});
test('question loading time does not extend the displayed deadline',()=>{
  const p=page('exam.html',async()=>({data:[]}));
  p.run("Date.now=()=>110000;startTimer({deadline_at:new Date(160000).toISOString(),server_now:new Date(100000).toISOString(),received_at:100000})");
  assert.match(p.get('timer').textContent,/00:50/);
});
