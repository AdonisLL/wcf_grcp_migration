---
phase_id: {{phase_id}}
migration_spec_id: {{migration_spec_id}}
generated_at: {{generated_at_utc}}
---

# Integration Checkpoint Report — {{phase_id}}

**Wave(s) reconciled:** {{waves_reconciled}}
**Work packages merged at this checkpoint:** {{work_package_ids}}

This report reconciles parallel work before the next wave may begin. It does
not authorize WCF retirement.

## Preconditions checked

- All listed work packages reported `completed` or an accepted `partial`
  state: {{completion_confirmation}}
- No unresolved ownership conflicts among merged packages: {{conflict_check}}

## Reconciliation performed

| Area | Check | Result |
|---|---|---|
| Generated code | {{generated_code_check_description}} | {{result}} |
| Shared contracts (`.proto`) | {{shared_contract_check_description}} | {{result}} |
| DI registration | {{di_registration_check_description}} | {{result}} |
| Configuration | {{configuration_check_description}} | {{result}} |

## Build and test results

| Command | Working directory | Result |
|---|---|---|
| `{{command}}` | `{{working_directory}}` | {{result}} |

## New risks or conflicts surfaced

{{new_risks_or_conflicts_or_none}}

## Outcome

- Checkpoint reconciled: {{reconciled_yes_no}}
- Next wave may begin: {{next_wave_permission}}
- Next required action: {{next_required_action}}
