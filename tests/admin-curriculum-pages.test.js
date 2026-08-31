const assert=require('assert'),fs=require('fs'),p=require('path');
const read=f=>fs.readFileSync(p.join(__dirname,'../public',f),'utf8');
const structure=read('admin-school-structure.html')+read('admin-school-structure.js');
['v5_admin_create_academic_year','v5_admin_set_active_academic_year','v5_admin_add_class','curriculum-structure.svg'].forEach(x=>assert.ok(structure.includes(x),`structure missing ${x}`));
const questions=read('admin-curriculum-question-bank.html')+read('admin-curriculum-question-bank.js');
['formBook','formChapter','formTopic','formSubtopic','multiple_choice','descriptive','v5_admin_save_curriculum_question'].forEach(x=>assert.ok(questions.includes(x),`questions missing ${x}`));
const exams=read('admin-curriculum-exam-builder.html')+read('admin-curriculum-exam-builder.js');
['examKind','academicYear','classIds','book','chapter','topic','subtopic','school','konkur','v5_staff_build_curriculum_exam'].forEach(x=>assert.ok(exams.includes(x),`exams missing ${x}`));
console.log('PASS admin curriculum pages');
