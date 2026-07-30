---
artifact_id: {{migration_spec_id}}
artifact_type: target-architecture
schema_version: 1.0.0
approval_state: {{approval_state}}
inventory_id: {{inventory_id}}
decision_log_id: {{decision_log_id}}
source_digest: {{source_digest}}
---

# Target gRPC Architecture

## Architecture summary

{{architecture_summary}}

## Design sections

| Topic | State | Design | Decisions | Risks | Evidence |
|---|---|---|---|---|---|
| Target runtime | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Hosting | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Service boundaries | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Protobuf/versioning | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Data types/presence | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Errors | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Security | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Authorization | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Deadlines/retries | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Observability | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Health checks | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Deployment | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Coexistence | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Consumer cutover | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |
| Retirement | {{state}} | {{design_or_unresolved}} | {{decision_ids}} | {{risk_ids}} | {{evidence_ids}} |

## Topology

### Nodes

| Node | Kind | Name | Source IDs |
|---|---|---|---|
| {{node_id}} | {{node_kind}} | {{node_name}} | {{source_ids}} |

### Connections

| From | To | Protocol | Purpose | Coexistence only |
|---|---|---|---|---:|
| {{from_node}} | {{to_node}} | {{protocol}} | {{purpose}} | {{coexistence_only}} |

## Cross-cutting policies

Every statement below is rendered from the linked design sections, decisions,
and risks in `migration-spec.json`. Do not introduce a claim here that the
structured artifact does not contain.

### Protobuf package, versioning, and file layout

| Service | Proto file | Package | API version | Imports |
|---|---|---|---|---|
| {{service_id}} | `{{proto_file}}` | `{{proto_package_or_unresolved}}` | {{api_version_or_unresolved}} | {{proto_imports}} |

Shared contracts: `{{shared_proto_path}}`  
Generated-code owner: {{generated_code_owner}}  
Field numbering and reservation policy: {{field_numbering_policy}}  
Breaking-change and deprecation policy: {{breaking_change_policy}}

### Protobuf compatibility

{{protobuf_compatibility_policy}}

### Security and authorization

{{security_policy}}

### Errors, deadlines, retries, and cancellation

{{reliability_policy}}

### State, sessions, and duplex redesign

| Legacy construct | Affected IDs | gRPC redesign | Behavior change | Risk | Decision |
|---|---|---|---|---|---|
| {{legacy_state_construct}} | {{affected_ids}} | {{state_redesign}} | {{behavior_change}} | {{risk_id}} | {{decision_id}} |

### Transactions and reliable delivery redesign

| Legacy construct | Affected IDs | gRPC redesign | Consistency/delivery change | Risk | Decision |
|---|---|---|---|---|---|
| {{legacy_transaction_construct}} | {{affected_ids}} | {{consistency_redesign}} | {{delivery_change}} | {{risk_id}} | {{decision_id}} |

### Observability, health, and operations

{{operations_policy}}

### Hosting and deployment

{{hosting_deployment_policy}}

## Coexistence, cutover, and rollback

{{coexistence_cutover_summary}}

## Open blockers

| Question ID | Topic | Why blocking | Next action |
|---|---|---|---|
| {{question_id}} | {{topic}} | {{why_blocking}} | {{next_action}} |

## Evidence

| Evidence ID | Claim | Locator | Confidence |
|---|---|---|---|
| {{evidence_id}} | {{claim}} | `{{locator}}` | {{confidence}} |
