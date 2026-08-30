import 'package:flutter_test/flutter_test.dart';
import 'package:marefat_student_demo/models/student_models.dart';

void main() {
  test('StudentSession parses login RPC payload', () {
    final session = StudentSession.fromJson({
      'token': 'abc',
      'expires_at': '2026-08-31T01:00:00Z',
      'student_id': 2,
      'student_code': 'STAGING-STUDENT-001',
      'student_name': 'دانش‌آموز آزمایشی اول',
    });
    expect(session.token, 'abc');
    expect(session.studentCode, 'STAGING-STUDENT-001');
  });

  test('DashboardData parses attempts and summary', () {
    final dashboard = DashboardData.fromJson({
      'profile': {
        'student_code': 'STAGING-STUDENT-001',
        'full_name': 'دانش‌آموز آزمایشی اول',
      },
      'summary': {
        'attempt_count': 2,
        'submitted_count': 1,
        'in_progress_count': 1,
        'visible_result_count': 1,
        'average_percentage': 75,
        'correct_count': 3,
        'wrong_count': 1,
        'blank_count': 0,
      },
      'attempts': [
        {
          'attempt_id': '00000000-0000-0000-0000-000000000001',
          'exam_code': 'STAGING-EXAM-001',
          'exam_title': 'آزمون سه‌سؤالی محیط تست',
          'status': 'started',
          'result_visible': false,
          'detail_visible': false,
          'can_resume': true,
        }
      ],
    });
    expect(dashboard.profile.fullName, 'دانش‌آموز آزمایشی اول');
    expect(dashboard.summary.attemptCount, 2);
    expect(dashboard.attempts.single.canResume, isTrue);
  });

  test('ExamQuestion groups option rows without correctness data', () {
    final questions = ExamQuestion.fromRpcRows([
      {
        'id': 11,
        'question_order': 1,
        'score': 1,
        'question_text': 'نمونه سؤال',
        'option_id': 101,
        'option_key': 'A',
        'option_text': 'گزینه اول',
        'sort_order': 1,
      },
      {
        'id': 11,
        'question_order': 1,
        'score': 1,
        'question_text': 'نمونه سؤال',
        'option_id': 102,
        'option_key': 'B',
        'option_text': 'گزینه دوم',
        'sort_order': 2,
      }
    ]);
    expect(questions, hasLength(1));
    expect(questions.single.options, hasLength(2));
    expect(questions.single.options.first.key, 'A');
  });
}
