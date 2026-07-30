---
artifact_id: {{migration_spec_id}}
artifact_type: migration-roadmap
schema_version: 1.0.0
approval_state: {{approval_state}}
inventory_id: {{inventory_id}}
decision_log_id: {{decision_log_id}}
source_digest: {{source_digest}}
---

# WCF-to-gRPC Migration Roadmap

## Strategy

{{roadmap_strategy}}

Pilot service: {{pilot_service_id_or_unresolved}}

## Dependency-ordered phases

| Sequence | Phase ID | Phase | Objective | Depends on | Work packages | Integration checkpoint |
|---:|---|---|---|---|---|---:|
| {{sequence}} | {{phase_id}} | {{phase_title}} | {{phase_objective}} | {{depends_on_phase_ids}} | {{work_package_ids}} | {{integration_checkpoint}} |

### {{phase_id}} exit criteria

| Criterion ID | Observable result | Required evidence | Validation IDs |
|---|---|---|---|
| {{criterion_id}} | {{criterion}} | {{evidence_required}} | {{validation_ids}} |

## Fleet waves

| Wave | Parallel group | Eligible work packages | Sequential/integration owner | Ownership conflicts |
|---:|---|---|---|---|
| {{wave}} | {{parallel_group}} | {{eligible_work_package_ids}} | {{integration_owner_ids}} | {{conflict_or_none}} |

## Consumer migration and coexistence

{{consumer_migration_plan}}

## WCF retirement criteria

| Criterion ID | Observable result | Required evidence | Validation IDs |
|---|---|---|---|
| {{criterion_id}} | {{criterion}} | {{evidence_required}} | {{validation_ids}} |

WCF retirement remains blocked until every criterion is satisfied and the
retirement decision is explicitly approved.

## Risks and blockers

| ID | Type | State | Affected phase/work package | Next action |
|---|---|---|---|---|
| {{risk_or_question_id}} | {{type}} | {{state}} | {{affected_ids}} | {{next_action}} |
