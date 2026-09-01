const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(require('node:path').join(__dirname,'../public/student-auth.js'),'utf8');
function harness(initial=null,rawLocation='/index.html'){
 let saved=initial,calls=[],redirect=null,domHandler=null;
 const url=new URL(rawLocation,'https://example.test');
 const storage={getItem:()=>saved,setItem:(_k,v)=>{saved=v},removeItem:()=>{saved=null}};
 const raw={rpc:async(name,args)=>{calls.push([name,args]);return name==='v5_student_login'?{data:{token:'a'.repeat(64),expires_at:'2099-01-01T00:00:00Z',student_id:2,student_code:'S-2',student_name:'Test'}}:{data:{ok:true}}}};
 const ctx=vm.createContext({globalThis:null,sessionStorage:storage,Date,URLSearchParams,
  location:{pathname:url.pathname,search:url.search,replace:v=>{redirect=v}},document:{addEventListener:(_n,h)=>{domHandler=h},getElementById:()=>null},
  supabase:{createClient:()=>raw}});ctx.globalThis=ctx;vm.runInContext(source,ctx);
 return {api:ctx.MarefatStudentAuth,client:ctx.supabase.createClient('u','k'),calls,get saved(){return saved},get redirect(){return redirect},runDom:()=>domHandler?.()};
}
(async()=>{
 const h=harness();assert.equal(typeof h.api.login,'function');
 await h.api.login(' Student-1 ','correct-password');assert.match(JSON.parse(h.saved).token,/^[a-f0-9]{64}$/);
 const result=await h.client.rpc('v5_start_exam',{p_token:'exam',p_student_code:'ignored'});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_start_exam',{p_exam_token:'exam',p_session_token:'a'.repeat(64)}]);assert.deepEqual(result,{data:{ok:true}});
 await h.client.rpc('v5_save_answer',{p_attempt_id:'attempt',p_exam_question_id:12,p_selected_option_id:34,p_student_code:'ignored'});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_save_answer',{p_attempt_id:'attempt',p_exam_question_id:12,p_selected_option_id:34,p_session_token:'a'.repeat(64)}]);
 await h.client.rpc('v5_save_descriptive_answer',{p_attempt_id:'attempt',p_exam_question_id:13,p_answer_text:' پاسخ تشریحی '});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_save_descriptive_answer',{p_attempt_id:'attempt',p_exam_question_id:13,p_answer_text:' پاسخ تشریحی ',p_session_token:'a'.repeat(64)}]);
 await h.client.rpc('v5_get_student_result',{p_attempt_id:'attempt',p_student_code:'another-student'});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_get_result_v2',{p_attempt_id:'attempt',p_session_token:'a'.repeat(64)}]);
 await h.client.rpc('v5_dashboard',{p_limit:25});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_dashboard_v2',{p_limit:25,p_session_token:'a'.repeat(64)}]);
 await h.client.rpc('v5_resume_attempt',{p_attempt_id:'attempt-a'});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_resume_attempt',{p_attempt_id:'attempt-a',p_session_token:'a'.repeat(64)}]);
 const bad=harness('{not json');bad.api.requireSession();assert.match(bad.redirect,/student-login\.html/);
 const expired=harness(JSON.stringify({token:'a'.repeat(64),expires_at:'2020-01-01T00:00:00Z'}));assert.equal(expired.api.getSession(),null);
 const loginPage=harness(null,'/student-login.html');assert.equal(loginPage.redirect,null);
 const dashboardPage=harness(null,'/student-dashboard.html');assert.match(dashboardPage.redirect,/student-login\.html\?return=student-dashboard\.html/);
 const publicIndex=harness(null,'/index.html');assert.equal(publicIndex.redirect,null);
 assert.equal(h.api.safeReturn('student-dashboard.html'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('student-dashboard.html?token=abc'),'student-dashboard.html?token=abc');
 assert.equal(h.api.safeReturn('student-dashboard.html?token=abc&return=https://evil.example'),'student-dashboard.html?token=abc');
 assert.equal(h.api.safeReturn('student-dashboard.html?token=abc&foo=bar'),'student-dashboard.html?token=abc');
 assert.equal(h.api.safeReturn('https://evil.example'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('//evil.example'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('admin-panel.html'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('exam.html?token=good'),'exam.html?token=good');
 assert.equal(h.api.safeReturn('exam.html?token=good&foo=bar'),'exam.html?token=good');
 assert.equal(h.api.safeReturn('exam.html?attempt=owned-id&token=public-token'),'exam.html?attempt=owned-id');
 assert.equal(h.api.safeReturn('exam.html?attempt=owned-id&token=public-token&foo=bar'),'exam.html?attempt=owned-id');
 assert.equal(h.api.safeReturn('student-result.html?attempt=result-id&foo=bar'),'student-result.html?attempt=result-id');
 assert.equal(h.api.safeReturn('student-dashboard.html#frag'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('student-dashboard.html%2fadmin'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('student-dashboard.html?token=abc%23frag'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('exam.html?token=good%2Fbad'),'student-dashboard.html');
 assert.equal(h.api.safeReturn('student-result.html?attempt=result-id%26admin=true'),'student-dashboard.html');
 await h.api.logout();assert.equal(h.saved,null);assert.equal(h.calls.at(-1)[0],'v5_student_logout');
 console.log('PASS: student login storage, RPC mapping, expiry, redirect and logout');
})().catch(e=>{console.error(e);process.exitCode=1});
