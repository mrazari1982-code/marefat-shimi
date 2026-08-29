const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(require('node:path').join(__dirname,'../public/student-auth.js'),'utf8');
function harness(initial=null,path='/index.html'){
 let saved=initial,calls=[],redirect=null,domHandler=null;
 const storage={getItem:()=>saved,setItem:(_k,v)=>{saved=v},removeItem:()=>{saved=null}};
 const raw={rpc:async(name,args)=>{calls.push([name,args]);return name==='v5_student_login'?{data:{token:'a'.repeat(64),expires_at:'2099-01-01T00:00:00Z',student_id:2,student_code:'S-2',student_name:'Test'}}:{data:{ok:true}}}};
 const ctx=vm.createContext({globalThis:null,sessionStorage:storage,Date,URLSearchParams,
  location:{pathname:path,search:'',replace:v=>{redirect=v}},document:{addEventListener:(_n,h)=>{domHandler=h},getElementById:()=>null},
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
 await h.client.rpc('v5_get_student_result',{p_attempt_id:'attempt',p_student_code:'another-student'});
 assert.deepEqual(JSON.parse(JSON.stringify(h.calls.at(-1))),['v5_student_get_result',{p_attempt_id:'attempt',p_session_token:'a'.repeat(64)}]);
 const bad=harness('{not json');bad.api.requireSession();assert.match(bad.redirect,/student-login\.html/);
 const expired=harness(JSON.stringify({token:'a'.repeat(64),expires_at:'2020-01-01T00:00:00Z'}));assert.equal(expired.api.getSession(),null);
 const loginPage=harness(null,'/student-login.html');assert.equal(loginPage.redirect,null);
 assert.equal(h.api.safeReturn('https://evil.example'),'index.html');
 assert.equal(h.api.safeReturn('//evil.example'),'index.html');
 assert.equal(h.api.safeReturn('exam.html?token=good'),'exam.html?token=good');
 await h.api.logout();assert.equal(h.saved,null);assert.equal(h.calls.at(-1)[0],'v5_student_logout');
 console.log('PASS: student login storage, RPC mapping, expiry, redirect and logout');
})().catch(e=>{console.error(e);process.exitCode=1});
