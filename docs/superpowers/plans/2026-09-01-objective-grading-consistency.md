# Objective grading consistency fix

## Goal

Keep objective answer rows and attempt counters consistent when a mixed objective/descriptive attempt is submitted and later manually graded.

## Implementation

1. Add a database regression test that submits a correct objective answer plus a descriptive answer, then verifies the objective row, attempt counters, and final score after manual grading.
2. Add one forward-only migration replacing `v5_student_submit_attempt` and `v5_admin_grade_descriptive_answer`.
3. On submission, normalize every objective answer from the snapshotted selected option: persist `is_correct` and `score_awarded`, then aggregate attempt counters and scores from the normalized rows.
4. On manual grading, recompute objective counters as well as total score and percentage so existing inconsistent attempts self-heal when the final descriptive answer is graded.
5. Preserve pending-manual result masking, authorization, fixed `search_path`, grants, deadlines, and idempotency protections.
6. Run the focused red/green test on staging, the full local suite, Supabase advisors, code review, then publish through a supplemental PR and apply the migration to production after merge.

## Verification

- Correct objective choice persists `is_correct=true` and full `score_awarded`.
- Wrong objective choice persists `is_correct=false` and zero score.
- Missing objective answer contributes to `blank_count`.
- Manual grading preserves/recalculates correct, wrong, and blank counters.
- Pending results remain hidden until all answered descriptive questions are graded.
