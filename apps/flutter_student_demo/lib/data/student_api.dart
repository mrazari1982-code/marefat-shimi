import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student_models.dart';

class StudentApiException implements Exception { StudentApiException(this.message); final String message; @override String toString()=>message; }

class StudentApi {
  StudentApi(this.client);
  final SupabaseClient client;

  Future<StudentSession> login(String username,String password) async {
    final raw=await client.rpc('v5_student_login',params:{'p_username':username.trim(),'p_password':password});
    if(raw==null || raw is! Map) throw StudentApiException('نام کاربری یا رمز عبور نادرست است.');
    final session=StudentSession.fromJson(Map<String,dynamic>.from(raw));
    if(session.token.isEmpty) throw StudentApiException('ورود انجام نشد.');
    return session;
  }
  Future<DashboardData> dashboard(String token) async => DashboardData.fromJson(Map<String,dynamic>.from(await client.rpc('v5_student_dashboard',params:{'p_session_token':token,'p_limit':100}) as Map));
  Future<ExamStart> startExam(String examToken,String token) async => ExamStart.fromJson(Map<String,dynamic>.from(await client.rpc('v5_student_start_exam',params:{'p_exam_token':examToken.trim(),'p_session_token':token}) as Map));
  Future<ExamStart> resumeAttempt(String attemptId,String token) async => ExamStart.fromJson(Map<String,dynamic>.from(await client.rpc('v5_student_resume_attempt',params:{'p_attempt_id':attemptId,'p_session_token':token}) as Map));
  Future<AttemptState> attemptState(String attemptId,String token) async => AttemptState.fromJson(Map<String,dynamic>.from(await client.rpc('v5_student_get_attempt_state',params:{'p_attempt_id':attemptId,'p_session_token':token}) as Map));
  Future<List<ExamQuestion>> questions(String attemptId,String token) async { final rows=await client.rpc('v5_student_get_exam_questions',params:{'p_attempt_id':attemptId,'p_session_token':token}); return ExamQuestion.fromRpcRows(rows is List ? rows : const []); }
  Future<void> saveAnswer(String attemptId,int questionId,int optionId,String token) async { await client.rpc('v5_student_save_answer',params:{'p_attempt_id':attemptId,'p_exam_question_id':questionId,'p_selected_option_id':optionId,'p_session_token':token}); }
  Future<StudentResult> submit(String attemptId,String token) async { await client.rpc('v5_student_submit_attempt',params:{'p_attempt_id':attemptId,'p_session_token':token}); return result(attemptId,token); }
  Future<StudentResult> result(String attemptId,String token) async => StudentResult.fromJson(Map<String,dynamic>.from(await client.rpc('v5_student_get_result',params:{'p_attempt_id':attemptId,'p_session_token':token}) as Map));
  Future<void> logout(String token) async { await client.rpc('v5_student_logout',params:{'p_session_token':token}); }
}
