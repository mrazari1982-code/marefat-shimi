num? _num(Object? value) => value is num ? value : num.tryParse('$value');
int _int(Object? value) => _num(value)?.toInt() ?? 0;
double? _doubleOrNull(Object? value) => value == null ? null : _num(value)?.toDouble();
bool _bool(Object? value) => value == true;
String _str(Object? value) => value?.toString() ?? '';
Map<String, dynamic> _map(Object? value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class StudentSession {
  const StudentSession({required this.token, required this.expiresAt, required this.studentId, required this.studentCode, required this.studentName});
  factory StudentSession.fromJson(Map<String, dynamic> json) => StudentSession(
    token: _str(json['token']), expiresAt: DateTime.tryParse(_str(json['expires_at'])),
    studentId: _int(json['student_id']), studentCode: _str(json['student_code']), studentName: _str(json['student_name']));
  final String token; final DateTime? expiresAt; final int studentId; final String studentCode; final String studentName;
}

class StudentProfile {
  const StudentProfile({required this.studentCode, required this.fullName, this.gradeName, this.fieldName, this.className});
  factory StudentProfile.fromJson(Map<String,dynamic> json) => StudentProfile(studentCode:_str(json['student_code']), fullName:_str(json['full_name']), gradeName:json['grade_name']?.toString(), fieldName:json['field_name']?.toString(), className:json['class_name']?.toString());
  final String studentCode; final String fullName; final String? gradeName; final String? fieldName; final String? className;
}

class DashboardSummary {
  const DashboardSummary({required this.attemptCount, required this.submittedCount, required this.inProgressCount, required this.visibleResultCount, required this.correctCount, required this.wrongCount, required this.blankCount, this.averagePercentage});
  factory DashboardSummary.fromJson(Map<String,dynamic> json) => DashboardSummary(attemptCount:_int(json['attempt_count']), submittedCount:_int(json['submitted_count']), inProgressCount:_int(json['in_progress_count']), visibleResultCount:_int(json['visible_result_count']), averagePercentage:_doubleOrNull(json['average_percentage']), correctCount:_int(json['correct_count']), wrongCount:_int(json['wrong_count']), blankCount:_int(json['blank_count']));
  final int attemptCount, submittedCount, inProgressCount, visibleResultCount, correctCount, wrongCount, blankCount; final double? averagePercentage;
}

class AttemptSummary {
  const AttemptSummary({required this.attemptId, required this.examCode, required this.examTitle, required this.status, required this.resultVisible, required this.detailVisible, required this.canResume, this.percentage, this.correctCount, this.wrongCount, this.blankCount, this.resumeReason});
  factory AttemptSummary.fromJson(Map<String,dynamic> json) => AttemptSummary(attemptId:_str(json['attempt_id']), examCode:_str(json['exam_code']), examTitle:_str(json['exam_title']), status:_str(json['status']), resultVisible:_bool(json['result_visible']), detailVisible:_bool(json['detail_visible']), canResume:_bool(json['can_resume']), percentage:_doubleOrNull(json['percentage']), correctCount:json['correct_count']==null?null:_int(json['correct_count']), wrongCount:json['wrong_count']==null?null:_int(json['wrong_count']), blankCount:json['blank_count']==null?null:_int(json['blank_count']), resumeReason:json['resume_reason']?.toString());
  final String attemptId, examCode, examTitle, status; final bool resultVisible, detailVisible, canResume; final double? percentage; final int? correctCount, wrongCount, blankCount; final String? resumeReason;
}

class DashboardData {
  const DashboardData({required this.profile, required this.summary, required this.attempts});
  factory DashboardData.fromJson(Map<String,dynamic> json) => DashboardData(profile:StudentProfile.fromJson(_map(json['profile'])), summary:DashboardSummary.fromJson(_map(json['summary'])), attempts:(json['attempts'] is List ? json['attempts'] as List : const []).map((e)=>AttemptSummary.fromJson(_map(e))).toList());
  final StudentProfile profile; final DashboardSummary summary; final List<AttemptSummary> attempts;
}

class ExamStart {
  const ExamStart({required this.attemptId, required this.status, required this.title, required this.durationMinutes});
  factory ExamStart.fromJson(Map<String,dynamic> json) => ExamStart(attemptId:_str(json['attempt_id']), status:_str(json['status']), title:_str(json['title']), durationMinutes:_int(json['duration_minutes']));
  final String attemptId, status, title; final int durationMinutes;
}

class AttemptState {
  const AttemptState({required this.attemptId, required this.status, required this.answers, this.deadlineAt, this.serverNow});
  factory AttemptState.fromJson(Map<String,dynamic> json) => AttemptState(attemptId:_str(json['attempt_id']), status:_str(json['status']), deadlineAt:DateTime.tryParse(_str(json['deadline_at'])), serverNow:DateTime.tryParse(_str(json['server_now'])), answers:{for(final item in (json['answers'] is List ? json['answers'] as List : const [])) _int(_map(item)['exam_question_id']): _int(_map(item)['selected_option_id'])});
  final String attemptId, status; final DateTime? deadlineAt, serverNow; final Map<int,int> answers;
}

class QuestionOption {
  const QuestionOption({required this.id, required this.key, required this.text, required this.sortOrder});
  final int id, sortOrder; final String key, text;
}

class ExamQuestion {
  const ExamQuestion({required this.id, required this.order, required this.text, required this.score, required this.options});
  static List<ExamQuestion> fromRpcRows(List<dynamic> rows) {
    final grouped=<int,List<Map<String,dynamic>>>{};
    for(final row in rows){final m=_map(row); grouped.putIfAbsent(_int(m['id']),()=>[]).add(m);} 
    final result=grouped.entries.map((entry){final first=entry.value.first; final options=entry.value.map((m)=>QuestionOption(id:_int(m['option_id']),key:_str(m['option_key']),text:_str(m['option_text']),sortOrder:_int(m['sort_order']))).toList()..sort((a,b)=>a.sortOrder.compareTo(b.sortOrder)); return ExamQuestion(id:entry.key,order:_int(first['question_order']),text:_str(first['question_text']),score:_num(first['score'])?.toDouble()??0,options:options);}).toList()..sort((a,b)=>a.order.compareTo(b.order));
    return result;
  }
  final int id, order; final String text; final double score; final List<QuestionOption> options;
}

class StudentResult {
  const StudentResult({required this.attemptId, required this.examTitle, required this.resultVisible, required this.detailVisible, this.percentage, this.correctCount, this.wrongCount, this.blankCount});
  factory StudentResult.fromJson(Map<String,dynamic> json) => StudentResult(attemptId:_str(json['attempt_id']), examTitle:_str(json['exam_title']), resultVisible:_bool(json['result_visible']), detailVisible:_bool(json['detail_visible']), percentage:_doubleOrNull(json['percentage']), correctCount:json['correct_count']==null?null:_int(json['correct_count']), wrongCount:json['wrong_count']==null?null:_int(json['wrong_count']), blankCount:json['blank_count']==null?null:_int(json['blank_count']));
  final String attemptId, examTitle; final bool resultVisible, detailVisible; final double? percentage; final int? correctCount, wrongCount, blankCount;
}
