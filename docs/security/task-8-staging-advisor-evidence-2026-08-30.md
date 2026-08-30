# Task 8 staging security evidence — 2026-08-30

Scope: Supabase staging project `yyqeymyopawhaniyemqo`. Production project was not queried for writes and was not changed.

## Migration ledger

The staging migration ledger contains:

```text
20260830085333 | student_dashboard_and_resume
```

The repository migration is therefore named `supabase/migrations/20260830085333_student_dashboard_and_resume.sql`. This is a ledger reconciliation only; staging history was not rewritten.

## Privileged RPC catalog and ACL

| Function | Security definer | Fixed search path | PUBLIC execute | anon | authenticated |
| --- | --- | --- | --- | --- | --- |
| `v5_student_dashboard(text,integer)` | yes | `pg_catalog, public, v5_auth_private` | no | yes | yes |
| `v5_student_resume_attempt(uuid,text)` | yes | `pg_catalog, public, v5_auth_private` | no | yes | yes |
| `v5_student_get_result(uuid,text)` | yes | `pg_catalog, public, v5_auth_private` | no | yes | yes |

The `anon`/`authenticated` grants are intentional for the custom student-login model. Each RPC resolves the student from the opaque session token inside the privileged function and scopes attempt reads by the resolved student; browser-supplied student identity is not an authorization input.

Direct privilege checks also show no schema usage or table SELECT for `anon` on `v5_auth_private.credentials` and `v5_auth_private.sessions`, and no SELECT for `authenticated` on either table.

## Advisor snapshot

Security advisor: 85 notices.

| Lint | Count | Interpretation for this branch |
| --- | ---: | --- |
| `rls_enabled_no_policy` | 5 | Existing tables; private auth tables intentionally have no client policy and no client grants. |
| `anon_security_definer_function_executable` | 14 | Includes student RPCs intentionally callable before Supabase Auth; opaque-session validation and ownership checks occur in the functions. |
| `authenticated_security_definer_function_executable` | 66 | Broad existing advisor surface; no claim of a clean pre-branch baseline is made. |

Performance advisor: 94 notices.

| Lint | Count |
| --- | ---: |
| `unindexed_foreign_keys` | 3 |
| `auth_rls_initplan` | 7 |
| `unused_index` | 83 |
| `duplicate_index` | 1 |

No before-snapshot was captured, so this report does not claim every advisor item predates the branch. The branch-specific gate is based on direct catalog/ACL inspection and the ownership/visibility SQL suites.

## Rollback

Rollback is forward-only:

1. Deploy a frontend compatible with the previous RPC surface.
2. Restore the previous `v5_student_get_result(uuid,text)` wrapper and exact ACLs in a compensating migration.
3. Revoke and drop `v5_student_dashboard(text,integer)` and `v5_student_resume_attempt(uuid,text)` in that migration.
4. Keep the migration ledger append-only; never delete or rewrite the applied staging/production migration record.

No student, exam, attempt, answer, or result row is deleted by this rollback.

## Production execution

After explicit user approval, Supabase applied the same reviewed SQL to production under the tool-generated ledger entry:

```text
20260830145021 | student_dashboard_and_resume
```

The MCP migration API generates its own timestamp and does not accept a caller-supplied version, so production and staging have different ledger versions for the same named SQL migration. Neither ledger was manually edited. Post-apply catalog checks confirmed all three RPCs, fixed search paths, `PUBLIC EXECUTE=false`, intentional `anon`/`authenticated` grants, and continued denial of direct private-table reads.
