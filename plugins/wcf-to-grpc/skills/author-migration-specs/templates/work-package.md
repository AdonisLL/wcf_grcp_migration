---
artifact_id: {{work_package_id}}
artifact_type: work-package
schema_version: 1.0.0
approval_state: {{approval_state}}
migration_spec_id: {{migration_spec_id}}
source_digest: {{source_digest}}
---

# {{work_package_id}} — {{work_package_title}}

**Status:** {{status}}  
**Objective:** {{objective}}

## Scope

{{scope_items}}

## Non-goals

{{non_goal_items}}

## Trace sources

- Inventory/source IDs: {{source_ids}}
- Contract specifications: {{spec_ids}}
- Decisions: {{decision_ids}}
- Risks: {{risk_ids}}
- Evidence: {{evidence_ids}}

## Specification reference

- Contract specifications: {{spec_ids}}
- Migration specification artifact: `{{migration_spec_id}}`

## Dependencies

| Work package | Type | State | Reason |
|---|---|---|---|
| {{dependency_work_package_id}} | {{dependency_type}} | {{dependency_state}} | {{dependency_reason}} |

## Fleet suitability and file ownership

- Suitability: **{{fleet_suitability}}**
- Rationale: {{fleet_rationale}}
- Wave: {{wave_or_unresolved}}
- Parallel group: {{parallel_group_or_unresolved}}
- Conflicts with: {{conflicting_work_package_ids_or_none}}

| Path | Ownership mode | Reason |
|---|---|---|
| `{{path}}` | {{ownership_mode}} | {{ownership_reason}} |

Do not edit paths outside this table without returning the deviation to the
orchestrator. `shared-read` does not grant write ownership.

## Deliverables

| Path | Action | Description |
|---|---|---|
| `{{deliverable_path}}` | {{action}} | {{description}} |

## Acceptance criteria

| Criterion ID | Observable result | Required evidence | Validation IDs |
|---|---|---|---|
| {{criterion_id}} | {{criterion}} | {{evidence_required}} | {{validation_ids}} |

## Validation

| Validation ID | Kind | Working directory | Command/check | Expected result | Initial state |
|---|---|---|---|---|---|
| {{validation_id}} | {{kind}} | `{{working_directory}}` | `{{command_or_manual_check}}` | {{expected_result}} | {{validation_state}} |

## Coexistence

- Required: {{coexistence_required}}
- Strategy: {{coexistence_strategy}}
- Traffic control: {{traffic_control}}
- Duration/exit condition: {{coexistence_exit_condition}}
- Legacy endpoint retained: {{legacy_endpoint_retained}}

## Rollback

- Strategy: {{rollback_strategy}}
- Triggers: {{rollback_triggers}}
- Data impact: {{rollback_data_impact}}
- Owner: {{rollback_owner}}

Ordered steps:

{{rollback_steps}}

Rollback validation: {{rollback_validation_ids}}

## Integration checkpoints

{{integration_checkpoints}}

## Completion report requirements

Report changed files, commands and results, acceptance evidence, assumptions,
new risks or decisions, deviations from this package, coexistence state, and
rollback readiness. Completion does not authorize WCF retirement.
