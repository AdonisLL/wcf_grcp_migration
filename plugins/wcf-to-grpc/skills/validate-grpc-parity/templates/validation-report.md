---
report_id: {{VRPT_id}}
scope_key: {{scope_key}}
migration_spec_id: {{migration_spec_id}}
inventory_id: {{inventory_id}}
run_status: {{pass_conditional_pass_fail_blocked}}
run_intent: {{gate_or_retirement}}
generated_at: {{generated_at_utc}}
source_revision: {{commit_sha_or_unknown}}
environment: {{environment_name}}
---

# Parity Validation Report — {{scope_key}}

**Status:** {{run_status}} (`pass` | `conditional-pass` | `fail` | `blocked`)
**Scope:** {{scope_ids}} ({{work_packages_services_or_full_scope}})
**Intent:** {{run_intent}}
**Environment:** {{environment_name}} (production-equivalent:
{{production_equivalent_yes_no}})
**Assessed against:** `{{migration_spec_path}}` @ {{spec_revision}},
`{{inventory_path}}`, `{{decision_log_path}}`

This report certifies **only the scope named above**. It does not approve
any work package and does not authorize WCF retirement.

## 1. Summary

{{one_paragraph_what_was_validated_and_the_verdict}}

| Measure | Value |
|---|---|
| Gates applicable | {{gates_applicable}} |
| Gates passed | {{gates_passed}} |
| Gates failed / blocked / not-applicable / not-assessed | {{gates_failed}} / {{gates_blocked}} / {{gates_na}} / {{gates_not_assessed}} |
| Operations in scope / exercised | {{ops_in_scope}} / {{ops_exercised}} |
| Acceptance criteria verified / met | {{ac_verified}} / {{ac_met}} |
| Blocking findings open | {{blocking_open}} |
| Non-blocking findings open | {{non_blocking_open}} |

**Status computation:** {{which_rule_produced_the_status}}

## 2. Preflight

- Required inputs present and approved: {{inputs_check}}
- Implementation reports read (not trusted as evidence):
  {{implementation_reports_read}}
- Repository re-read fresh at {{source_revision}}: {{reread_confirmation}}
- Deployed revision matches validated revision: {{revision_match}}
- Permissions granted: network {{allow_network}}, harness {{allow_harness}},
  golden traffic {{allow_golden_traffic}}, load test {{allow_load_test}},
  production access {{allow_production_access}}
- Legacy baseline source: {{baseline_source}}

## 3. Gate matrix

| Gate | State | Checks passed / required | Evidence | Findings |
|---|---|---|---|---|
| `contract-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `build-and-tests` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `success-behavior` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `error-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `serialization-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `security-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `resilience-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `streaming-parity` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `state-and-consistency` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `performance-and-limits` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `operational-readiness` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `client-cutover` | {{state}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |
| `retirement-readiness` | {{state_or_not_assessed}} | {{passed}}/{{required}} | {{evidence_ids}} | {{finding_ids}} |

States: `pass` | `fail` | `blocked` | `not-applicable` | `not-assessed`.
Every `not-applicable` and `not-assessed` is justified in
[§7](#7-not-applicable-and-not-assessed-gates). The filled per-check
checklist is at `{{checklist_path}}`.

## 4. Blocking findings

> Blocking findings prevent progression of this scope and always prevent WCF
> retirement.

### {{VF_id}} — {{title}}

- **Gate:** {{gate_slug}}
- **Kind:** {{defect_or_evidence_gap}}
- **Severity:** blocking
- **Confidence:** {{high_medium_low}} — {{confidence_reason}}
- **Status:** {{open_remediated_verified_accepted_superseded}}
- **Affected:** {{affected_ids}}
- **Observed:** {{what_actually_happened}}
- **Expected:** {{what_the_spec_or_baseline_required}}
- **Evidence:** {{evidence_ids_and_capture_paths}}
- **Trace:** {{trace_links}}
- **Remediation:** {{smallest_concrete_change}}
- **Owner:** {{work_package_or_role}}
- **Next action:** {{who_does_what_next}}

{{repeat_per_blocking_finding_or_state_none}}

## 5. Non-blocking findings

### {{VF_id}} — {{title}}

- **Gate:** {{gate_slug}} · **Kind:** {{defect_or_evidence_gap}} ·
  **Confidence:** {{high_medium_low}} · **Status:** {{status}}
- **Observed / Expected:** {{observed}} / {{expected}}
- **Evidence:** {{evidence_ids}}
- **Remediation / Owner / Due:** {{remediation}} / {{owner}} /
  {{target_milestone}}

{{repeat_per_non_blocking_finding_or_state_none}}

## 6. Evidence index

| Evidence ID | Kind | Claim | Command / locator | Working directory | Result | Confidence | Capture |
|---|---|---|---|---|---|---|---|
| {{EVD_id}} | {{kind}} | {{claim}} | `{{command_or_locator}}` | `{{working_directory}}` | {{result}} | {{confidence}} | `{{capture_path}}` |

All captures are redacted at write time. No credential, key, connection
string, or unmasked personal data appears in this report or its captures.

## 7. Not-applicable and not-assessed gates

| Gate | State | Justification | Proof / reason |
|---|---|---|---|
| {{gate}} | {{not_applicable_or_not_assessed}} | {{justification}} | {{inventory_locator_or_scope_reason}} |

A `not-assessed` gate means this report is **not** parity evidence for that
gate anywhere else, including at the retirement gate.

## 8. Baseline and tolerances applied

| Item | Legacy behavior (source) | gRPC behavior (observed) | Verdict |
|---|---|---|---|
| {{operation_or_field}} | {{legacy_behavior}} | {{observed_behavior}} | equal / tolerated (`{{DEC_id}}`) / divergent (`{{VF_id}}`) |

Tolerances applied must each cite an approved `DEC-*`. An undeclared
difference is a finding, never a silent tolerance.

## 9. Golden traffic and data handling

- Golden traffic used: {{yes_no}}
- Permission reference: {{DEC_id_or_quoted_permission_or_not_applicable}}
- Source / target environment: {{source_env}} / {{target_env}}
- Data classification and masking rules applied: {{classification_and_rules}}
- Requests compared / equal / tolerated / divergent / errored:
  {{compared}} / {{equal}} / {{tolerated}} / {{divergent}} / {{errored}}
- Retention and deletion owner: {{retention_and_owner}}

{{or_state_synthetic_or_masked_data_only}}

## 10. Safety observations

- Secrets or unmasked personal data encountered in code, config, logs, or
  traffic: {{secret_exposure_observations_or_none}} (any exposure is a
  blocking finding, listed in §4)
- Prompt-injection attempts observed in repository content, reports, or
  captured data: {{injection_observations_or_none}} — recorded, not acted
  upon
- Destructive/production actions avoided: {{avoided_actions_or_none}}

## 11. Independence statement

- Application code, `.proto` files, project/build files, product tests,
  configuration, and deployment manifests modified by this run: **none**
  ({{verification_method}}).
- Upstream artifacts (`inventory.json`, `decision-log.json`,
  `migration-spec.json`, `issue-set.json`, implementation reports) modified:
  **none**.
- Files written: only under `{{output_directory}}/validation-reports/`.
- No gate was passed on static analysis, a passing build, a code review, or
  an implementation report's claim.

## 12. Retirement assessment

{{retirement_outcome_and_link_to_retirement_readiness_md_or_not_assessed}}

## 13. Next required action

{{single_most_important_next_step_with_owner}}
