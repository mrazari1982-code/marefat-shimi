const SUPABASE_URL='https://rbqlblryxcaodvyrnfuo.supabase.co';
const SUPABASE_KEY='sb_publishable_iJkwgMHRaBQjFhk_0QSU1w_aSKWG1mU';
// Client-side helper: call the existing secured RPC after an exam is published.
async function ensurePublishedExamLink(supabaseClient, examId){
  const {data,error}=await supabaseClient.rpc('v5_ensure_exam_link',{p_exam_id:examId});
  if(error) throw error;
  return data;
}
