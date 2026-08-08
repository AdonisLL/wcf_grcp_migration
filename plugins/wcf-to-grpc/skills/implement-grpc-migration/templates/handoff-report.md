---
work_package_id: {{work_package_id}}
migration_spec_id: {{migration_spec_id}}
report_status: {{status}}
attempt_id: {{attempt_id}}
generated_at: {{generated_at_utc}}
---

# Implementation Report — {{work_package_id}}

**Status:** {{status}} (`completed` | `partial` | `blocked`)
**Objective (from spec):** {{objective}}
**Run mode:** {{mode}} (`implement` | `resume`)
**Spec package sub-digest:** `{{semantic_sub_digest}}`

This report does not claim runtime parity with WCF, does not assert
deployment readiness, does not authorize WCF retirement, and does not
approve its own work package.

## Preflight verification

- Work package status/approval confirmed: {{status_approval_confirmation}}
- Hard dependencies satisfied: {{hard_dependency_check}}
- Fleet wave/ownership/conflict check: {{fleet_check_result}}
- Claim marker written: `{{claim_marker_path}}`
- Current repository state re-read (not assumed): {{reread_confirmation}}
- Execution capability handshake: {{capability_check_result}}
- Immutable WCF/content-manifest check: {{protected_manifest_check}}

## Changed projects and files

| Path | Action | Ownership mode | Notes |
|---|---|---|---|
| `{{path}}` | {{create_modify_delete_verify}} | {{ownership_mode}} | {{notes}} |

## Commands executed

| Validation ID | Kind | Working directory | Command | Result | Evidence |
|---|---|---|---|---|---|
| {{validation_id}} | {{kind}} | `{{working_directory}}` | `{{command}}` | {{passed_failed_blocked}} | {{evidence_summary}} |

## Acceptance evidence

| Criterion ID | Met? | Evidence observed |
|---|---|---|
| {{criterion_id}} | {{met_or_not_met}} | {{evidence_detail}} |

## Assumptions

{{assumptions_list_or_none}}

## New risks or decisions discovered

{{new_risks_or_decisions_or_none}}

## Code gaps / deviations from the package

For each deviation, use:

```text
Kind: {{deviation_kind}}
Blocks: {{blocked_deliverable_or_ac_id}}
What was found: {{actual_vs_assumed}}
Why it blocks: {{consequence}}
Next action: {{smallest_unblocking_step}}
```

{{deviations_or_none}}

## Coexistence state

- Legacy WCF endpoint untouched and locally runnable: {{coexistence_state}}
- Schema/proto changes made are additive and backward compatible: {{additive_confirmation}}
- Matches package's coexistence plan: {{plan_match_confirmation}}

## Code rollback

- `git revert` / file-removal steps: {{rollback_steps}}
- Local build result after revert (WCF and shared projects still compile/run): {{rollback_local_build_result}}

> Rollback is limited to code revert and local compatibility verification.
> Live traffic drain, service restart, and load-balancer changes are outside
> this skill's scope.

## Offline dependencies

| Package / SDK / Tool | Version required | Source / feed |
|---|---|---|
| {{name}} | {{version}} | {{feed}} |

## Reviewed versus resolved dependencies

| Package | Reviewed direct version | Effective resolved version | Drift disposition |
|---|---|---|---|
| {{package}} | {{reviewed_version}} | {{resolved_version}} | {{matched_approved_exception_blocked}} |

## Content-manifest evidence

| Path | Classification / ownership | Before SHA-256 | After SHA-256 | Result |
|---|---|---|---|---|
| `{{manifest_path}}` | {{classification_or_owner}} | `{{before_hash}}` | `{{after_hash}}` | {{unchanged_or_expected_change}} |

## Attempt lineage

- Previous attempt: {{previous_attempt_id_or_none}}
- Supersedes: {{superseded_attempt_id_or_none}}
- Resolved blockers: {{resolved_blocker_ids_or_none}}

## Final sequential integration checkpoint

| Command | Working directory | Result |
|---|---|---|
| `{{build_command}}` | `{{working_directory}}` | {{build_result}} |
| `{{test_command}}` | `{{working_directory}}` | {{test_result}} |

> **Scope of this checkpoint:** Confirms the code compiles and existing
> repository-local tests pass. It does **not** constitute runtime parity
> evidence, WCF behavior equivalence, or deployment readiness.

## Integration checkpoint participation (fleet)

{{integration_checkpoint_notes_or_not_applicable}}

## Prompt-injection / anomaly observations

{{injection_observations_or_none}}

## Next required action

{{next_required_action}}
