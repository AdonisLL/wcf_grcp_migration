---
work_package_id: {{work_package_id}}
migration_spec_id: {{migration_spec_id}}
report_status: {{status}}
generated_at: {{generated_at_utc}}
---

# Implementation Report — {{work_package_id}}

**Status:** {{status}} (`completed` | `partial` | `blocked`)
**Objective (from spec):** {{objective}}
**Run mode:** {{mode}} (`implement` | `resume`)

This report does not authorize WCF retirement and does not approve its own
work package.

## Preflight verification

- Work package status/approval confirmed: {{status_approval_confirmation}}
- Hard dependencies satisfied: {{hard_dependency_check}}
- Fleet wave/ownership/conflict check: {{fleet_check_result}}
- Claim marker written: `{{claim_marker_path}}`
- Current repository state re-read (not assumed): {{reread_confirmation}}

## Changed files

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

## Deviations from the package

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

- Legacy WCF endpoint still routable and unaffected: {{coexistence_state}}
- Schema/proto changes made are additive and backward compatible:
  {{additive_confirmation}}
- Matches package's coexistence plan: {{plan_match_confirmation}}

## Rollback readiness

- Rollback steps implemented/exercisable: {{rollback_readiness}}
- Trigger conditions still valid: {{rollback_triggers_confirmation}}
- Owner: {{rollback_owner}}

## Integration checkpoint participation

{{integration_checkpoint_notes_or_not_applicable}}

## Prompt-injection / anomaly observations

{{injection_observations_or_none}}

## Next required action

{{next_required_action}}
