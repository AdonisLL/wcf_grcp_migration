---
report_id: {{VRPT_id}}
scope: {{retirement_scope}}
outcome: {{retirement_ready_not_ready_blocked}}
generated_at: {{generated_at_utc}}
source_revision: {{deployed_revision}}
---

# WCF Retirement Readiness — {{retirement_scope}}

**Outcome:** {{outcome}} (`retirement-ready` | `retirement-not-ready` |
`retirement-blocked`)
**Validation report:** `{{validation_report_path}}` ({{VRPT_id}})
**Environment assessed:** {{environment_name}} (production-equivalent:
{{yes_no}})

This is a **readiness assessment, not an authorization**. Retirement
requires a separate human approval recorded in the decision log, referencing
{{VRPT_id}}. Conditions are normative in
[`../references/retirement-gate.md`](../references/retirement-gate.md).

## 1. Criteria satisfaction

| Criterion (`AC-*`) | Statement | Evidence required | Evidence observed | Met? |
|---|---|---|---|---|
| {{AC_id}} | {{statement}} | {{evidence_required}} | {{EVD_ids}} | {{yes_no}} |

## 2. Parity coverage across the retirement scope

| Service / consumer | Gates 1–12 state | Blocking findings open | Evidence current for deployed revision? |
|---|---|---|---|
| {{SVC_or_CON_id}} | {{summary}} | {{count_and_ids}} | {{yes_no_with_revision}} |

## 3. Consumers

| Consumer (`CON-*`) | State | Evidence | Coexistence path | End-of-service date |
|---|---|---|---|---|
| {{CON_id}} | migrated / waived (`{{DEC_id}}`) / not-migrated | {{EVD_ids}} | {{path_or_none}} | {{date_or_na}} |

- Unknown callers on WCF endpoints: {{count}} ({{measurement_source}})
- Quiesce window measured: {{window}} — observed traffic:
  {{traffic_measurement}}

## 4. Operations

| Condition | State | Evidence |
|---|---|---|
| Health probes correct incl. dependency-down | {{state}} | {{EVD}} |
| Telemetry (logs/traces/metrics) in production-equivalent env | {{state}} | {{EVD}} |
| Alerting able to detect post-retirement regression | {{state}} | {{EVD}} |
| Runbook/on-call material references the gRPC service | {{state}} | {{EVD}} |
| Capacity evidence for 100% of traffic | {{state}} | {{EVD}} |

## 5. Rollback and coexistence

| Condition | State | Evidence |
|---|---|---|
| Rollback rehearsed (date, operator, environment, result) | {{state}} | {{EVD}} |
| Rollback path available for the agreed post-retirement period | {{state}} | {{EVD}} |
| Temporary coexistence components removed or scheduled with owners | {{state}} | {{EVD}} |
| Coexistence-period data migrations additive/reversible | {{state}} | {{EVD}} |

## 6. Unmet conditions

| Condition | Why unmet | Owner | Next action |
|---|---|---|---|
| {{condition}} | {{missing_evidence_or_defect}} | {{owner}} | {{smallest_step}} |

{{or_state_none}}

## 7. Accepted residual risk

| Finding | Severity | Accepting decision | Residual risk after retirement |
|---|---|---|---|
| {{VF_id}} | {{severity}} | {{DEC_id}} | {{residual_risk}} |

{{or_state_none}}

## 8. Decision record status

- Human retirement approval present: {{yes_no}} ({{DEC_id_or_missing}})
- Approval references this assessment: {{yes_no}}
- This stage did **not** record, request, or imply that approval.

## 9. Post-retirement follow-up

| Item | Owner | Due |
|---|---|---|
| Remove rollback path | {{owner}} | {{date}} |
| Delete temporary coexistence component `{{component}}` | {{owner}} | {{date}} |
| Resolve non-blocking finding {{VF_id}} | {{owner}} | {{milestone}} |
| Keep regression monitoring `{{monitor}}` in place | {{owner}} | {{duration}} |

## 10. Statement

{{explicit_sentence_stating_whether_retirement_may_proceed_and_what_remains}}
