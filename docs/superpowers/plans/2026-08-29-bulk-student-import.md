# Bulk Student Excel Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an admin-only Excel workflow that previews and atomically imports up to 500 students, generates unique passwords, and downloads a confidential credential workbook.

**Architecture:** A focused browser module validates normalized workbook rows and generates passwords with Web Crypto. A security-definer batch RPC repeats all trust-boundary validation, inserts students plus bcrypt credentials in one transaction, and reports existing codes without changing them. A separate admin page uses a pinned, self-hosted ExcelJS bundle to create the template and result workbooks.

**Tech Stack:** Static HTML/JavaScript, ExcelJS 4.4.0 browser bundle, Supabase/Postgres 17, pgcrypto/crypt bcrypt, Node.js VM tests, SQL transactional tests, Cloudflare Workers static assets.

**Spec:** `docs/superpowers/specs/2026-08-29-bulk-student-import-design.md`

## Global Constraints

- Accept only `.xlsx` files no larger than 2 MiB and no more than 500 nonempty data rows.
- Required Persian headers are exactly `کد دانش‌آموزی` and `نام و نام خانوادگی`; `پایه`، `رشته` and `کلاس` are optional.
- Generate 12-character passwords with `crypto.getRandomValues` from `ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789`.
- Never persist, log, or return plaintext passwords from the database.
- Existing student codes are skipped and their credentials are never changed.
- New rows are atomic: an unexpected error rolls back every insertion in that RPC call.
- Only active `admin` and `deputy` profiles may call the context and import RPCs.
- ExcelJS must be pinned at 4.4.0 and served locally; add no runtime CDN dependency.
- Production rollout follows staging tests, security review, GitHub PR, compatible database migration, frontend verification, then final ACL verification.

---

## File Map

- Create `public/student-import.js`: pure normalization, validation, password generation, and result-model functions.
- Create `public/vendor/exceljs-4.4.0.min.js`: pinned local browser bundle.
- Create `public/admin-student-import.html`: authorization, workbook I/O, preview, confirmation, RPC, and downloads.
- Create `supabase/migrations/20260829150000_bulk_student_import.sql`: context and atomic import RPCs plus ACL.
- Create `tests/student-import-browser.cjs`: unit tests for the pure browser module.
- Create `tests/student-import-db.sql`: transactional role, validation, hashing, duplicate, and rollback tests.
- Create `tests/student-import-page.cjs`: page wiring and asset-order checks.
- Modify `public/students.html`: navigation link to group import.
- Modify `tests/deployment-safety.py`: permit only the two new JavaScript assets and require the new route.

---

### Task 1: Pure import rules and password generator

**Files:**
- Create: `tests/student-import-browser.cjs`
- Create: `public/student-import.js`

**Interfaces:**
- Consumes: browser `crypto.getRandomValues(Uint32Array)`.
- Produces: `MarefatStudentImport.validateRows(rows, context)`, `generatePassword(randomSource?)`, and `credentialRows(validatedRows, rpcResults)`.
- `context` shape: `{grades:[{id,name}],fields:[{id,name}],classes:[{id,name,grade_id,field_id}],existingCodes:string[]}`.
- Validated row shape: `{rowNumber,student_code,full_name,grade_id,field_id,class_id,grade_name,field_name,class_name,status,errors}`.

- [ ] **Step 1: Write the failing browser-module test**

```js
const assert=require('node:assert/strict');
const vm=require('node:vm');
const fs=require('node:fs');
const source=fs.readFileSync('public/student-import.js','utf8');
const ctx=vm.createContext({globalThis:null,crypto:{getRandomValues:a=>{for(let i=0;i<a.length;i++)a[i]=i;return a}}});
ctx.globalThis=ctx; vm.runInContext(source,ctx);
const api=ctx.MarefatStudentImport;
const context={
 grades:[{id:1,name:'دهم'}],fields:[{id:2,name:'ریاضی'}],
 classes:[{id:3,name:'۱۰۱',grade_id:1,field_id:2}],existingCodes:['OLD-1']
};
const rows=[
 {'کد دانش‌آموزی':'0012','نام و نام خانوادگی':'علی رضایی','پایه':'دهم','رشته':'ریاضی','کلاس':'۱۰۱'},
 {'کد دانش‌آموزی':'OLD-1','نام و نام خانوادگی':'موجود'},
 {'کد دانش‌آموزی':'0012','نام و نام خانوادگی':'تکراری'}
];
const out=api.validateRows(rows,context);
assert.equal(out[0].student_code,'0012');
assert.equal(out[0].status,'valid');
assert.equal(out[1].status,'existing');
assert.equal(out[2].status,'invalid');
assert.match(out[2].errors.join(' '),/تکراری/);
const password=api.generatePassword();
assert.equal(password.length,12);
assert.doesNotMatch(password,/[0OIl1]/);
```

- [ ] **Step 2: Run the test and verify RED**

Run: `node tests/student-import-browser.cjs`  
Expected: FAIL because `public/student-import.js` does not exist.

- [ ] **Step 3: Implement the minimal pure module**

```js
(function(global){
 const HEADERS=['کد دانش‌آموزی','نام و نام خانوادگی','پایه','رشته','کلاس'];
 const ALPHABET='ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
 const clean=value=>String(value??'').trim();
 const key=value=>clean(value).toLocaleLowerCase('fa');
 function generatePassword(randomSource){
  const values=new Uint32Array(12);
  (randomSource||global.crypto.getRandomValues.bind(global.crypto))(values);
  return Array.from(values,n=>ALPHABET[n%ALPHABET.length]).join('');
 }
 function validateRows(rows,context){
  const seen=new Map(),existing=new Set(context.existingCodes.map(key));
  const gradeByName=new Map(context.grades.map(x=>[key(x.name),x]));
  const fieldByName=new Map(context.fields.map(x=>[key(x.name),x]));
  const classByName=new Map(context.classes.map(x=>[key(x.name),x]));
  const normalized=rows.map((raw,index)=>{
   const student_code=clean(raw[HEADERS[0]]),full_name=clean(raw[HEADERS[1]]);
   const grade=gradeByName.get(key(raw[HEADERS[2]])),field=fieldByName.get(key(raw[HEADERS[3]])),klass=classByName.get(key(raw[HEADERS[4]]));
   const errors=[]; if(!student_code)errors.push('کد دانش‌آموزی الزامی است.'); if(!full_name)errors.push('نام الزامی است.');
   if(clean(raw[HEADERS[2]])&&!grade)errors.push('پایه ناشناخته است.');
   if(clean(raw[HEADERS[3]])&&!field)errors.push('رشته ناشناخته است.');
   if(clean(raw[HEADERS[4]])&&!klass)errors.push('کلاس ناشناخته است.');
   if(klass&&((grade&&klass.grade_id!==grade.id)||(field&&klass.field_id!==field.id)))errors.push('کلاس با پایه یا رشته سازگار نیست.');
   return {rowNumber:index+2,student_code,full_name,grade_id:grade?.id||null,field_id:field?.id||null,class_id:klass?.id||null,grade_name:grade?.name||'',field_name:field?.name||'',class_name:klass?.name||'',status:errors.length?'invalid':existing.has(key(student_code))?'existing':'valid',errors};
  });
  normalized.forEach(row=>{const k=key(row.student_code);if(!k)return;if(seen.has(k)){row.status='invalid';row.errors.push('کد داخل فایل تکراری است.');const first=normalized[seen.get(k)];first.status='invalid';if(!first.errors.includes('کد داخل فایل تکراری است.'))first.errors.push('کد داخل فایل تکراری است.');}else seen.set(k,row.rowNumber-2);});
  return normalized;
 }
 function credentialRows(rows,results){const byCode=new Map(results.map(x=>[key(x.student_code),x]));return rows.map(row=>({...row,password:byCode.get(key(row.student_code))?.status==='created'?row.password:'',server_status:byCode.get(key(row.student_code))?.status||row.status}));}
 global.MarefatStudentImport={HEADERS,validateRows,generatePassword,credentialRows};
})(globalThis);
```

- [ ] **Step 4: Extend the test for blank rows, unknown lookups, incompatible class, 501 rows, and credential filtering**

Add assertions that blank rows are removed before `validateRows`, invalid lookup names yield Persian errors, incompatible class combinations fail, the page adapter rejects more than 500 rows, and `credentialRows` blanks passwords for `existing`.

- [ ] **Step 5: Run and verify GREEN**

Run: `node tests/student-import-browser.cjs`  
Expected: `PASS: normalization, duplicates, lookups, passwords and credential filtering`.

- [ ] **Step 6: Commit**

```bash
git add public/student-import.js tests/student-import-browser.cjs
git commit -m "feat: add student import validation core"
```

---

### Task 2: Admin context and atomic batch RPC

**Files:**
- Create: `supabase/migrations/20260829150000_bulk_student_import.sql`
- Create: `tests/student-import-db.sql`

**Interfaces:**
- Produces `public.v5_admin_student_import_context() returns jsonb`.
- Produces `public.v5_admin_import_students(p_rows jsonb) returns jsonb`.
- Input item: `{student_code,full_name,grade_id,field_id,class_id,password}`.
- Output item: `{student_code,student_id,status}`, where status is `created` or `existing`.

- [ ] **Step 1: Write the transactional SQL test before the migration**

```sql
begin;
do $$ begin
 if to_regprocedure('public.v5_admin_import_students(jsonb)') is null then
  raise exception 'IMPORT_RPC_NOT_IMPLEMENTED';
 end if;
end $$;
rollback;
```

Then add test blocks that use a temporary authenticated admin fixture, call three rows (two new and one existing), assert two bcrypt hashes exist and do not contain plaintext, call login for one created account, and force an invalid class relation to assert the entire statement rolls back.

- [ ] **Step 2: Run on staging and verify RED**

Run with Supabase SQL execution against project `yyqeymyopawhaniyemqo`.  
Expected: `IMPORT_RPC_NOT_IMPLEMENTED`.

- [ ] **Step 3: Implement the migration with locked ACL**

```sql
create or replace function public.v5_admin_student_import_context()
returns jsonb language plpgsql security definer
set search_path=pg_catalog,public as $$
begin
 if not exists(select 1 from public.v5_profiles where id=auth.uid() and is_active and role in ('admin','deputy')) then
  raise exception 'ACCESS_DENIED' using errcode='42501';
 end if;
 return jsonb_build_object(
  'grades',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by level_order),'[]') from public.v5_grades where is_active),
  'fields',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name) order by name),'[]') from public.v5_fields where is_active),
  'classes',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'grade_id',grade_id,'field_id',field_id) order by name),'[]') from public.v5_classes where is_active),
  'existingCodes',(select coalesce(jsonb_agg(student_code order by student_code),'[]') from public.v5_students)
 );
end $$;
```

Implement `v5_admin_import_students` as one PL/pgSQL function that:

1. checks role;
2. rejects non-array input, zero items, more than 500 items, or payloads above 512 KiB;
3. validates required strings, password length 8–72 bytes, and unique codes within input;
4. validates every referenced active grade, field and class plus class relation before inserting anything;
5. loops rows, reports existing codes without update, inserts new `v5_students`, bcrypt-hashes password into `v5_auth_private.credentials`, and appends `created` results;
6. never includes password in returned JSON.

Finish with:

```sql
revoke all on function public.v5_admin_student_import_context() from public,anon;
revoke all on function public.v5_admin_import_students(jsonb) from public,anon;
grant execute on function public.v5_admin_student_import_context(),public.v5_admin_import_students(jsonb) to authenticated;
```

- [ ] **Step 4: Apply the migration to staging**

Apply only to `yyqeymyopawhaniyemqo` using the Supabase migration tool with name `bulk_student_import`.

- [ ] **Step 5: Run SQL tests and advisors**

Run `tests/student-import-db.sql` in staging and run Supabase security/performance advisors.  
Expected: PASS for role denial, batch insert, hashing, duplicate skip, atomic rollback, login, and ownership; no new unintended ACL warning.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/20260829150000_bulk_student_import.sql tests/student-import-db.sql
git commit -m "feat: add atomic student import RPC"
```

---

### Task 3: Pinned Excel workbook adapter and admin page

**Files:**
- Create: `public/vendor/exceljs-4.4.0.min.js`
- Create: `public/admin-student-import.html`
- Create: `tests/student-import-page.cjs`
- Modify: `public/student-import.js`

**Interfaces:**
- Consumes `window.ExcelJS.Workbook`, both RPCs from Task 2, and pure rules from Task 1.
- Produces template and credential `.xlsx` downloads and a preview table.

- [ ] **Step 1: Vendor the pinned ExcelJS bundle**

```bash
tmp_dir=$(mktemp -d)
npm pack exceljs@4.4.0 --pack-destination "$tmp_dir"
tar -xzf "$tmp_dir"/exceljs-4.4.0.tgz -C "$tmp_dir"
mkdir -p public/vendor
cp "$tmp_dir"/package/dist/exceljs.min.js public/vendor/exceljs-4.4.0.min.js
sha256sum public/vendor/exceljs-4.4.0.min.js
```

Record the printed checksum in the commit message body and verify the bundle contains the ExcelJS license header or add `public/vendor/EXCELJS-LICENSE.txt` from the package.

- [ ] **Step 2: Write the failing page wiring test**

```js
const html=require('node:fs').readFileSync('public/admin-student-import.html','utf8');
const assert=require('node:assert/strict');
assert.match(html,/vendor\/exceljs-4\.4\.0\.min\.js/);
assert.match(html,/student-import\.js/);
assert.match(html,/v5_admin_student_import_context/);
assert.match(html,/v5_admin_import_students/);
assert.match(html,/accept="\.xlsx"/);
assert.match(html,/دانلود قالب Excel/);
```

- [ ] **Step 3: Run and verify RED**

Run: `node tests/student-import-page.cjs`  
Expected: FAIL because the page does not exist.

- [ ] **Step 4: Build the page and workbook functions**

Create a Persian RTL page with:

- admin authorization identical to `admin-student-password.html`;
- buttons `downloadTemplate`, `chooseFile`, `importStudents`;
- a hidden `<input type="file" accept=".xlsx">`;
- counters for valid, existing and invalid rows;
- a preview table using `textContent` or escaped values only;
- confirmation text that states the exact number of new accounts;
- disabled submit while parsing or importing.

Add these adapter functions to `student-import.js`:

```js
async function readWorkbook(arrayBuffer,ExcelJS){
 const workbook=new ExcelJS.Workbook();
 await workbook.xlsx.load(arrayBuffer);
 const sheet=workbook.getWorksheet('دانش‌آموزان')||workbook.worksheets[0];
 if(!sheet)throw new Error('برگهٔ دانش‌آموزان پیدا نشد.');
 const headers=sheet.getRow(1).values.slice(1).map(clean);
 if(HEADERS.some((header,index)=>headers[index]!==header))throw new Error('ستون‌های فایل با قالب سامانه مطابقت ندارند.');
 const rows=[];
 sheet.eachRow((row,rowNumber)=>{
  if(rowNumber===1)return;
  const item=Object.fromEntries(HEADERS.map((header,index)=>[header,clean(row.getCell(index+1).text)]));
  if(Object.values(item).some(Boolean))rows.push(item);
 });
 if(rows.length>500)throw new Error('حداکثر ۵۰۰ دانش‌آموز در هر فایل مجاز است.');
 return rows;
}
async function buildTemplate(context,ExcelJS){
 const workbook=new ExcelJS.Workbook(),students=workbook.addWorksheet('دانش‌آموزان'),guide=workbook.addWorksheet('راهنما');
 students.addRow(HEADERS);students.views=[{state:'frozen',ySplit:1,rightToLeft:true}];students.autoFilter='A1:E1';
 students.getColumn(1).numFmt='@';[18,28,16,20,18].forEach((width,index)=>students.getColumn(index+1).width=width);
 guide.views=[{rightToLeft:true}];guide.addRow(['راهنمای ورود گروهی دانش‌آموزان']);guide.addRow(['حداکثر ردیف',500]);
 guide.addRow(['پایه‌های معتبر',context.grades.map(x=>x.name).join('، ')]);
 guide.addRow(['رشته‌های معتبر',context.fields.map(x=>x.name).join('، ')]);
 guide.addRow(['کلاس‌های معتبر',context.classes.map(x=>x.name).join('، ')]);
 return workbook.xlsx.writeBuffer();
}
async function buildCredentialWorkbook(rows,ExcelJS){
 const workbook=new ExcelJS.Workbook(),credentials=workbook.addWorksheet('اطلاعات ورود'),errors=workbook.addWorksheet('خطاها');
 credentials.addRow(['نام و نام خانوادگی','نام کاربری','رمز','پایه','رشته','کلاس','وضعیت']);
 errors.addRow(['شماره ردیف','کد دانش‌آموزی','علت']);
 rows.forEach(row=>{
  if(row.server_status==='created')credentials.addRow([row.full_name,row.student_code,row.password,row.grade_name,row.field_name,row.class_name,'ثبت شد']);
  else errors.addRow([row.rowNumber,row.student_code,row.errors.join('، ')||'از قبل موجود']);
 });
 credentials.getColumn(2).numFmt='@';credentials.views=[{state:'frozen',ySplit:1,rightToLeft:true}];errors.views=[{state:'frozen',ySplit:1,rightToLeft:true}];
 return workbook.xlsx.writeBuffer();
}
function downloadBlob(bytes,name){
 const url=URL.createObjectURL(new Blob([bytes],{type:'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'}));
 const anchor=document.createElement('a');anchor.href=url;anchor.download=name;anchor.click();setTimeout(()=>URL.revokeObjectURL(url),0);
}
```

Use typed text cells for student codes, freeze the header row, enable filters, wrap headers, set readable widths, and add the confidentiality warning to the result workbook.

- [ ] **Step 5: Generate passwords only after confirmation**

Map only `status==='valid'` rows to RPC payloads, attach one generated password per row, call `v5_admin_import_students`, merge results through `credentialRows`, download the workbook, then overwrite every in-memory `row.password` with an empty string.

- [ ] **Step 6: Run page, module, and syntax tests**

```bash
node tests/student-import-browser.cjs
node tests/student-import-page.cjs
node tests/html-script-syntax.cjs
node --check public/student-import.js
```

Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add public/vendor public/admin-student-import.html public/student-import.js tests/student-import-page.cjs
git commit -m "feat: add Excel student import page"
```

---

### Task 4: Navigation and deployment allowlist

**Files:**
- Modify: `public/students.html`
- Modify: `tests/deployment-safety.py`

**Interfaces:**
- Produces a visible `ورود گروهی از Excel` link for staff and permits only the exact new static assets.

- [ ] **Step 1: Add failing deployment assertions**

Require `admin-student-import.html`, `student-import.js`, `vendor/exceljs-4.4.0.min.js`, and the ExcelJS license file. Extend the allowlist by exact path, not by allowing arbitrary JavaScript or subdirectories.

- [ ] **Step 2: Run and verify RED**

Run: `python3 tests/deployment-safety.py`  
Expected: FAIL for missing required import route/assets.

- [ ] **Step 3: Add navigation and exact allowlist rules**

Add to `students.html`:

```html
<a class="btn" href="admin-student-import.html">ورود گروهی از Excel</a>
```

Update the safety test so the only permitted nested directory is `public/vendor`, containing only the pinned ExcelJS bundle and its license.

- [ ] **Step 4: Run all local regressions**

```bash
node tests/student-import-browser.cjs
node tests/student-import-page.cjs
node tests/html-script-syntax.cjs
node tests/student-auth-browser.cjs
node tests/exam-lifecycle.cjs
node tests/question-manager-selection.js
python3 tests/deployment-safety.py
git diff --check
```

Expected: all PASS and 0 diff-check errors.

- [ ] **Step 5: Commit**

```bash
git add public/students.html tests/deployment-safety.py
git commit -m "feat: link bulk student import workflow"
```

---

### Task 5: Staging integration and focused security review

**Files:**
- Modify tests only if a demonstrated staging defect requires a regression.

**Interfaces:**
- Validates the complete browser-to-RPC contract without leaving fixture accounts.

- [ ] **Step 1: Run a rollback staging batch**

Use three rows: one new, one existing, and one invalid class relationship. Confirm the invalid batch rolls back. Then run a valid batch in a separate transaction and confirm created/existing statuses, bcrypt hashes, login, logout, and cross-student denial. End every fixture transaction with `ROLLBACK`.

- [ ] **Step 2: Test generated workbooks locally**

Create a fixture workbook with numeric-looking code `0012`, Persian names, valid optional lookups, one duplicate and one invalid row. Parse it with the page adapter, inspect the preview model, export the credential workbook, reopen it, and assert the expected sheets, headers, text-preserved code and blank existing password.

- [ ] **Step 3: Request one focused security review**

Review only:

- RPC authorization and `search_path`;
- atomicity and race handling;
- plaintext password lifetime;
- XSS in preview/error rendering;
- workbook formula injection (prefix values beginning with `=`, `+`, `-`, or `@` as text);
- file size/row/payload limits;
- dependency pinning and deployment allowlist.

- [ ] **Step 4: Fix only verified findings with RED/GREEN tests**

For each accepted finding, first add a failing targeted test, then apply the smallest fix, then rerun Task 4's full regression command.

- [ ] **Step 5: Commit**

```bash
git add public tests supabase/migrations
git commit -m "fix: harden bulk student import"
```

Skip this commit if the review produces no code changes.

---

### Task 6: GitHub and production rollout

**Files:**
- No new source files; deploy the verified commits.

**Interfaces:**
- Produces the live route `/admin-student-import.html` and production RPCs.

- [ ] **Step 1: Fresh pre-release verification**

Run Task 4's complete local command, staging SQL tests, and Supabase advisors. Confirm the git worktree is clean.

- [ ] **Step 2: Push an atomic GitHub branch and open a PR**

Use the connected GitHub app to create the branch from current `main`, upload the exact tested tree, open a PR titled `ورود گروهی دانش‌آموزان از Excel`, and merge only if the expected head SHA matches.

- [ ] **Step 3: Apply the production migration**

Apply `20260829150000_bulk_student_import.sql` to project `rbqlblryxcaodvyrnfuo`. Immediately verify:

```sql
select
 has_function_privilege('authenticated','public.v5_admin_import_students(jsonb)','execute') authenticated_allowed,
 has_function_privilege('anon','public.v5_admin_import_students(jsonb)','execute') anon_denied;
```

Expected: `true, false`.

- [ ] **Step 4: Verify live static assets**

Fetch the live import page, core module and ExcelJS bundle with cache-busting query strings. Compare SHA-256 for both JavaScript assets against the tested local files and assert the page includes the import heading.

- [ ] **Step 5: Perform one real admin acceptance import**

Use a two-row workbook chosen by the manager: one new real student and one known existing student. Verify preview counts before submission, download the credential result, log in as the new student, and confirm the existing student's prior password still works.

- [ ] **Step 6: Final database verification**

Confirm the new student has one bcrypt credential, the existing credential hash is unchanged, no plaintext password appears in tables or function results, and an `anon` call is rejected.

- [ ] **Step 7: Report operational handoff**

Provide the live import URL, the exact acceptance results, instructions to secure/delete credential files after distribution, and the rollback boundary. Do not claim completion without fresh evidence from Steps 1–6.
