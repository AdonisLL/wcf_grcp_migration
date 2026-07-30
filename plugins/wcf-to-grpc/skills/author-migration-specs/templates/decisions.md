---
artifact_id: {{decision_log_id}}
artifact_type: decision-log
schema_version: 1.0.0
approval_state: {{approval_state}}
inventory_id: {{inventory_id}}
source_digest: {{source_digest}}
---

# WCF-to-gRPC Migration Decisions

## Decision summary

| Decision ID | Category | State | Selected option | Owner | Blocking questions |
|---|---|---|---|---|---|
| {{decision_id}} | {{category}} | {{state}} | {{selected_option_or_unresolved}} | {{owner}} | {{question_ids}} |

## {{decision_id}} — {{decision_title}}

**State:** {{state}}  
**Affected IDs:** {{affected_ids}}  
**Risks:** {{risk_ids}}  
**Evidence:** {{evidence_ids}}

### Context

{{context}}

### Options considered

| Option ID | Option | gRPC-centered | Advantages | Disadvantages | Consequences |
|---|---|---:|---|---|---|
| {{option_id}} | {{option_title}} | {{grpc_centered}} | {{advantages}} | {{disadvantages}} | {{consequences}} |

### Resolution

- Selected option: {{selected_option_or_unresolved}}
- Decision: {{decision_or_unresolved}}
- Rationale: {{rationale_or_unresolved}}
- Unresolved reason: {{unresolved_reason_or_not_applicable}}
- Next action: {{next_action_or_not_applicable}}
- Superseded by: {{superseded_by_or_not_applicable}}

### Approval history

| Approval ID | Reviewer | State | At | Note |
|---|---|---|---|---|
| {{approval_id}} | {{reviewer}} | {{approval_state}} | {{approval_time}} | {{approval_note}} |

## Evidence

| Evidence ID | Claim | Locator | Confidence |
|---|---|---|---|
| {{evidence_id}} | {{claim}} | `{{locator}}` | {{confidence}} |
