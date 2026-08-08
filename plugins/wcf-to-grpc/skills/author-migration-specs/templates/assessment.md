---
artifact_id: {{migration_spec_id}}
artifact_type: assessment
schema_version: 1.0.0
approval_state: {{approval_state}}
inventory_id: {{inventory_id}}
decision_log_id: {{decision_log_id}}
source_digest: {{source_digest}}
---

# WCF-to-gRPC Migration Assessment

## Executive summary

{{assessment_summary}}

## Scope

- Included: {{included_scope}}
- Excluded: {{excluded_scope}}
- Server migration: {{server_migration_state}}
- Client-only repository: {{client_only_state}}

## Current-state topology

| ID | Component | Role | Framework/host | Evidence |
|---|---|---|---|---|
| {{component_id}} | {{component_name}} | {{component_role}} | {{framework_or_host}} | [{{evidence_id}}] |

## Service and consumer inventory

| Service ID | Contract | Operations | Endpoints | Consumers | Analysis state |
|---|---|---:|---|---|---|
| {{service_id}} | {{contract_symbol}} | {{operation_count}} | {{endpoint_ids}} | {{consumer_ids}} | {{analysis_state}} |

## Dependency map

| Dependency ID | Kind | Affected IDs | Availability | Evidence |
|---|---|---|---|---|
| {{dependency_id}} | {{dependency_kind}} | {{affected_ids}} | {{availability}} | [{{evidence_id}}] |

## Complexity and risks

Overall complexity: **{{complexity}}**

| Risk ID | Severity | State | Affected IDs | Required action | Evidence |
|---|---|---|---|---|---|
| {{risk_id}} | {{severity}} | {{risk_state}} | {{affected_ids}} | {{required_action}} | [{{evidence_id}}] |

## Unresolved facts

`Blocking: true` identifies a migration gate. The **What it blocks** column
states whether that gate affects current code implementation or a later
offline milestone.

| Question ID | Blocking | Impact area | Why needed | What it blocks | Next decision |
|---|---:|---|---|---|---|
| {{question_id}} | {{blocking}} | {{impact_area}} | {{plain_language_why_needed}} | {{concrete_blocked_milestone_or_claim}} | {{decision_id_or_unassigned}} |

## Evidence

| Evidence ID | Claim | Locator | Confidence |
|---|---|---|---|
| {{evidence_id}} | {{claim}} | `{{locator}}` | {{confidence}} |
