<!--
wcf-to-grpc.issue:
  issue_id: {{issue_id}}
  work_package_id: {{work_package_id}}
  migration_spec_id: {{migration_spec_id}}
  issue_set_id: {{issue_set_id}}
  preview_digest: {{preview_digest}}
-->

# {{work_package_id}} - {{title}}

## Publication metadata

- Stable issue ID: `{{issue_id}}`
- Work package ID: `{{work_package_id}}`
- Migration spec ID: `{{migration_spec_id}}`
- Issue set ID: `{{issue_set_id}}`
- Target repository: `{{target_repository}}`
- Labels: {{labels}}
- Assignees: {{assignees}}
- Artifact approval: `{{work_package_approval}}`

## Objective

{{objective}}

## Scope

{{scope_items}}

## Non-goals

{{non_goal_items}}

## Deliverables

| Path | Action | Description |
|---|---|---|
| {{deliverable_path}} | {{deliverable_action}} | {{deliverable_description}} |

## Traceability

- Source IDs: {{source_ids}}
- Contract specifications: {{spec_ids}}
- Decisions: {{decision_ids}}
- Risks: {{risk_ids}}
- Evidence IDs: {{evidence_ids}}
- Acceptance IDs: {{acceptance_ids}}
- Validation IDs: {{validation_ids}}

## Dependencies

| Work package | Stable issue ID | Type | State | Reason | GitHub link after publish |
|---|---|---|---|---|---|
| {{dependency_work_package_id}} | `{{dependency_issue_id}}` | {{dependency_type}} | {{dependency_state}} | {{dependency_reason}} | <!-- depends-on:{{dependency_issue_id}} --> {{dependency_link_placeholder}} |

## Fleet suitability and file ownership

- Fleet suitability: **{{fleet_suitability}}**
- Rationale: {{fleet_rationale}}
- Wave: {{fleet_wave}}
- Parallel group: {{fleet_parallel_group}}

| Path | Ownership mode | Reason |
|---|---|---|
| `{{ownership_path}}` | {{ownership_mode}} | {{ownership_reason}} |

## Acceptance criteria

| ID | Observable result | Required evidence | Validation IDs |
|---|---|---|---|
| {{acceptance_id}} | {{acceptance_statement}} | {{acceptance_evidence}} | {{acceptance_validation_ids}} |

## Validation

| Validation ID | Kind | Working directory | Command/check | Expected result | Status |
|---|---|---|---|---|---|
| {{validation_id}} | {{validation_kind}} | `{{validation_working_directory}}` | {{validation_command_or_manual}} | {{validation_expected_result}} | {{validation_status}} |

## Coexistence and rollback

### Coexistence

- Required: {{coexistence_required}}
- Strategy: {{coexistence_strategy}}
- Traffic control: {{coexistence_traffic_control}}
- Exit condition: {{coexistence_exit_condition}}
- Legacy endpoint retained: {{legacy_endpoint_retained}}

### Rollback

- Strategy: {{rollback_strategy}}
- Triggers: {{rollback_triggers}}
- Data impact: {{rollback_data_impact}}
- Owner: {{rollback_owner}}
- Validation IDs: {{rollback_validation_ids}}

Ordered steps:

{{rollback_steps}}

## Integration checkpoints

{{integration_checkpoints}}

## Source evidence

| Evidence ID | Claim | Locator |
|---|---|---|
| {{evidence_id}} | {{evidence_claim}} | {{evidence_locator}} |
