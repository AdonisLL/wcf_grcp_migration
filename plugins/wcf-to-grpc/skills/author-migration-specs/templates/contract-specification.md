---
artifact_id: {{contract_spec_id}}
artifact_type: contract-specification
schema_version: 1.0.0
approval_state: {{approval_state}}
migration_spec_id: {{migration_spec_id}}
service_id: {{service_id}}
source_digest: {{source_digest}}
---

# {{service_name}} gRPC Contract Specification

## Contract identity

- Specification ID: `{{contract_spec_id}}`
- Source service: `{{service_id}}`
- Proto file: `{{proto_file}}`
- Package: `{{proto_package_or_unresolved}}`
- API version: `{{api_version_or_unresolved}}`
- Imports: {{proto_imports}}
- Decisions: {{decision_ids}}
- Risks: {{risk_ids}}

## RPC mapping

| RPC ID | RPC | Shape | Source operations | Request | Response | Deadline | Authorization | Errors |
|---|---|---|---|---|---|---|---|---|
| {{rpc_id}} | `{{rpc_name}}` | {{rpc_shape}} | {{source_operation_ids}} | `{{request_message}}` | `{{response_message}}` | {{deadline_policy}} | {{authorization_policy}} | {{error_policy}} |

### Streaming and lifecycle

{{streaming_lifecycle_notes}}

### Deadlines, cancellation, and idempotency

{{idempotency_retry_policy}}

## Message mapping

### `{{message_name}}` (`{{message_id}}`)

Source contracts: {{source_contract_ids}}

| Field ID | Number | Proto field | Type/cardinality | Source fields | Presence | Conversion | Validation | Evidence |
|---|---:|---|---|---|---|---|---|---|
| {{proto_field_id}} | {{field_number_or_unresolved}} | `{{field_name}}` | `{{protobuf_type}}` / {{cardinality}} | {{source_field_ids}} | {{presence_semantics}} | {{conversion_rules}} | {{validation_rules}} | {{evidence_ids}} |

Reserved numbers: {{reserved_numbers}}  
Reserved names: {{reserved_names}}

### Polymorphism

{{polymorphism_policy}}

## Fault and status mapping

| Source fault/risk | gRPC status | Rich detail | Client behavior | Decision |
|---|---|---|---|---|
| {{source_fault_id}} | {{grpc_status}} | {{detail_message}} | {{client_behavior}} | {{decision_id}} |

## Redesign notes for unsupported constructs

| Legacy construct | Affected operation/field | gRPC redesign | Behavior change | Risk | Decision |
|---|---|---|---|---|---|
| {{legacy_construct}} | {{affected_id}} | {{redesign}} | {{behavior_change}} | {{risk_id}} | {{decision_id}} |

## Compatibility rules

{{compatibility_rules}}

## Acceptance and validation

| Criterion ID | Observable result | Validation IDs |
|---|---|---|
| {{acceptance_criterion_id}} | {{criterion}} | {{validation_ids}} |

## Traceability

| Source ID | Relation | Target ID | State |
|---|---|---|---|
| {{from_id}} | {{relation}} | {{to_id}} | {{trace_state}} |

## Evidence

| Evidence ID | Claim | Locator | Confidence |
|---|---|---|---|
| {{evidence_id}} | {{claim}} | `{{locator}}` | {{confidence}} |
