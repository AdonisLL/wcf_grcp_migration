# Decision Log Persistence and Traceability Guidance

This reference defines how
[`interview-migration-decisions`](../SKILL.md) creates and incrementally
updates a decision log. The normative contracts are:

- [`decision-log.schema.json`](../../../schemas/decision-log.schema.json)
- [`common.schema.json`](../../../schemas/common.schema.json)
- [`inventory.schema.json`](../../../schemas/inventory.schema.json)

When this guidance and a schema differ, the schema wins.

## 1. Artifact envelope

Write a complete object, not a patch:

```json
{
  "schemaVersion": "1.0.0",
  "artifactType": "decision-log",
  "artifactId": "DLOG-example-repository",
  "generation": {},
  "approval": { "state": "draft" },
  "citations": [],
  "traceLinks": [],
  "inventoryId": "INV-example-repository",
  "decisions": []
}
```

- Derive `artifactId` from the repository identity and preserve it.
- Set `inventoryId` to the consumed inventory artifact ID.
- `generation.sourceDigest` covers the canonical inventory, prior decisions,
  sanitized interview answers, and generator version.
- Use `mode: incremental` whenever an existing decision log is updated.
- Sort ID-based arrays lexicographically. Use UTF-8, LF, two-space JSON, and
  one trailing newline.
- Persist atomically when tools permit: write/validate a sibling candidate,
  then replace the destination. Do not leave a partially written log.

## 2. Stable IDs

Create semantic IDs from canonical identities, never list positions or prompt
wording:

| ID | Canonical identity |
|---|---|
| `QST-*` | semantic topic + normalized affected-ID set + migration scope |
| `DEC-*` | semantic architecture choice + normalized affected-ID set |
| `OPT-*` | decision ID + option semantic key |
| `APV-*` | decision ID + reviewer/role + approval event time/state |
| `EVD-*` | sanitized answer or repository locator + claim category |
| `TRC-*` | from ID + relation + to ID |

Normalize keys to lowercase kebab case. On collision, append the first eight
lowercase hexadecimal characters of the SHA-256 canonical identity. Reuse
existing IDs even when labels or file locations change. Never recycle an ID
from a rejected, removed, obsolete, or superseded record.

Reuse inventory `QST-*` IDs whenever they represent the interview choice. For
a future-state business question not present in inventory, generate a
deterministic `QST-*` reference, retain the full prompt in the decision
`context`, and treat that ID as owned by the decision-log interview surface.
Do not alter the approved inventory merely to insert a question.

## 3. Decision states

### Unresolved and deferred

Use `state: unresolved` for unknown, unanswered, blocked, or deferred
decisions:

- `selectedOptionId`, `decision`, and `rationale` are `null`;
- `questionIds` contains at least one `QST-*`;
- `unresolvedReason` explains why it is unresolved;
- `nextAction` names the concrete resolution step;
- `owner` is a `known`, `unknown`, or `not-applicable` resolved string;
- `options` may list viable gRPC-centered choices but none is selected;
- `approvals` is normally empty.

The schema has no separate `deferred` state. Encode deferment as unresolved:

```json
{
  "state": "unresolved",
  "unresolvedReason": "Deferred to the platform security review before the pilot.",
  "nextAction": "Platform Security selects and approves the workload identity flow by the pilot design review.",
  "owner": { "state": "known", "value": "Platform Security" }
}
```

Do not use a fake option named `TBD`, an empty string, or a future date as a
decision.

### Proposed

Use `state: proposed` when an answer selects a viable option but explicit
approval has not occurred:

- selected option exists and has `grpcCentered: true`;
- `decision` states the choice precisely;
- `rationale` records the evidence, assumptions, and answer;
- `unresolvedReason` is `null`;
- `nextAction` may identify the required reviewer;
- `approvals` may contain `requested` events.

A conversational answer is proposed by default, even when it accepts the
skill's recommendation.

### Approved

Move to `approved` only after an explicit approval statement:

- retain all proposed fields;
- add at least one `APV-*` with `state: approved`;
- record reviewer as a resolved string;
- use a real UTC date-time;
- add a sanitized user-statement citation and link it to the decision;
- ensure the selected option is gRPC-centered.

Approval of a decision does not approve the containing artifact, authorize
cutover, or prove runtime parity.

### Rejected

Use `rejected` only for an explicitly rejected selected option:

- identify the rejected option;
- set `decision` to `null`;
- provide rationale;
- add a rejected approval event.

Continue with a separate unresolved/proposed successor decision when another
choice is still required.

### Superseded

Use `superseded` when a successor decision replaces the record:

- preserve the original ID, context, options, evidence, and approvals;
- set `supersededBy` to the successor `DEC-*`;
- explain why in `rationale`;
- add a `supersedes` trace link from successor to predecessor.

Never delete an approved or previously consumed decision.

## 4. Options and mandatory gRPC target

Every option contains:

- stable `OPT-*` ID;
- concise title and description;
- advantages, disadvantages, and consequences;
- `grpcCentered`.

For a proposed or approved selection, `grpcCentered` must be `true`. The
description must identify gRPC on ASP.NET Core as the service/API destination.

A supporting component is gRPC-centered only when:

1. gRPC remains the client/service contract or control boundary;
2. the component solves an evidenced semantic gap;
3. its ownership and operational consequences are explicit;
4. temporary bridges have retirement/exit conditions;
5. the user explicitly approves high-risk additions.

Examples of potentially valid supporting components are a broker behind a
gRPC acknowledgement API, Redis for externalized state, a saga/outbox for
cross-service consistency, or a temporary SOAP adapter in front of gRPC.
None is a valid permanent replacement for gRPC.

If the user requests REST, CoreWCF, SOAP, or a queue as the replacement target,
do not create a proposed/approved replacement option. Restate the mandatory
target and ask whether the technology is intended as a bounded supporting
component. If not, record the conflict as unresolved and block progression.

## 5. Evidence and user answers

Repository claims reuse inventory `EVD-*` citations. User answers create
deduplicated citations:

```json
{
  "id": "EVD-user-target-runtime",
  "kind": "user-statement",
  "claim": "The platform owner selected .NET 10 LTS for the gRPC host.",
  "locator": "user-statement:target-runtime",
  "confidence": "high",
  "observedAt": "2026-07-30T15:30:00Z"
}
```

The claim is a concise architectural fact, not a transcript. Never copy:

- passwords, access/refresh tokens, API keys, private keys;
- certificate bodies or private certificate identifiers when sensitive;
- connection strings or secret-store values;
- production payloads containing confidential or regulated data.

If a secret is supplied, omit/redact it, warn that it was not persisted, and
record only the safe policy-level answer. Do not place a secret in a digest,
excerpt, rationale, note, option, or approval.

## 6. Trace links

Use typed links from `common.schema.json`. IDs for nested inventory and
decision entities are valid stable IDs; use the containing artifact type in
the artifact reference.

Recommended links:

| From | Relation | To |
|---|---|---|
| inventory `QST-*` | `resolved-by` | decision-log `DEC-*` |
| inventory `RSK-*` | `resolved-by` | decision-log `DEC-*` |
| inventory entity | `raises` | inventory `QST-*`/`RSK-*` |
| decision-log `DEC-*` | `derived-from` | inventory entity |
| successor `DEC-*` | `supersedes` | predecessor `DEC-*` |

Use `state: unresolved` while the decision is unresolved, and `active` after
the decision becomes proposed/approved as appropriate. Include evidence IDs
supporting the relationship. Do not fabricate future specification IDs.

Each decision must also carry direct `affectedIds`, `riskIds`, and
`evidenceIds`; trace links supplement rather than replace those fields.

## 7. Deduplication and merge rules

Before creating a decision:

1. Find an existing record with the same canonical decision key.
2. If semantics match, reuse it and union `questionIds`, `affectedIds`,
   `riskIds`, and `evidenceIds`.
3. Merge options by semantic option key, preserving IDs and prior wording
   where meaning is unchanged.
4. Do not merge service-specific decisions merely because prompts are similar.
5. Do merge several source questions when one architecture choice resolves
   all of them.
6. Deduplicate user citations by sanitized claim and semantic locator.
7. Preserve approval events; never synthesize or coalesce distinct approvals.

When an answer makes another candidate irrelevant, remove it from the active
working queue. Do not delete a persisted decision; leave unresolved records
for review or supersede them when a new decision formally replaces them.

## 8. Inventory changes and stale answers

Compare the current inventory ID, source digest, affected IDs, risks,
evidence, and relevant resolved values with the basis recorded by each
decision.

### Non-material change

If evidence only adds compatible detail:

- preserve the decision ID, state, selected option, and approvals;
- add new evidence/affected IDs;
- update context without changing meaning;
- keep the answer non-stale.

### Material change to an unresolved/proposed decision

If assumptions, scope, risks, or viable options changed:

- preserve the ID when the semantic question is still the same;
- reset a proposed selection to `unresolved` if it is no longer justified;
- explain the evidence change in `unresolvedReason`;
- set a revalidation `nextAction`;
- require a new answer/approval.

Do not silently carry a selection across a changed consequence.

### Material change to an approved decision

Do not overwrite or silently downgrade the approved history:

1. Create a stable successor/revalidation `DEC-*`.
2. Keep the old decision approved until a replacement is approved.
3. Make the successor unresolved or proposed and block downstream approval.
4. After successor approval, mark the old decision `superseded` and set
   `supersededBy`.
5. Add a `supersedes` trace link and retain both records.

Examples of material changes:

- a newly discovered external uncontrolled consumer;
- new `decimal`, polymorphism, session, transaction, queue, duplex, or
  message-security evidence;
- changed service/operation scope;
- target platform no longer supports the approved runtime/transport;
- a compliance or SLA constraint that changes an option's acceptability;
- an inventory item previously treated as not applicable becomes applicable.

After any semantic inventory change, regenerate the decision log in
incremental mode and return its artifact approval to `draft` unless the
entire regenerated artifact is explicitly reapproved.

## 9. Approval gates

Decision-level gates:

- `unresolved`: blocks its dependent specification section;
- `proposed`: design may be drafted as proposed but is not executable;
- `approved`: may feed approved specification content;
- stale approved decision: blocks until successor approval;
- rejected/superseded: cannot be selected downstream.

Artifact-level gates:

- keep `approval.state: draft` while blocking decisions are unresolved,
  proposed, stale, or missing required approval;
- use `review-requested` only when blockers are resolved and named reviewers
  are requested;
- use `approved` only after explicit artifact approval, separate from
  individual decision approvals;
- cutover and WCF retirement remain separate decisions and require parity,
  consumer-migration, zero-traffic, rollback-readiness, and owner approval
  evidence.

At minimum, require explicit decision approval for:

- target runtime/platform;
- security identity/auth replacement and compliance exceptions;
- service boundary or operation retirement;
- Protobuf ownership/versioning and high-risk serialization choices;
- sessions, duplex, transactions, reliable delivery, queues, or message
  security redesign;
- external-client bridge/coexistence and its exit criteria;
- cutover, rollback, and WCF retirement;
- high-risk supporting technologies.

## 10. Complete examples

### Unresolved/deferred decision

```json
{
  "id": "DEC-order-service-identity-provider",
  "title": "Select the gRPC caller identity provider",
  "category": "security",
  "state": "unresolved",
  "questionIds": ["QST-order-service-identity-provider"],
  "context": "The WCF endpoint uses Windows authentication, which has no safe direct gRPC equivalent. EVD-order-windows-auth triggered this decision.",
  "options": [
    {
      "id": "OPT-order-service-identity-oidc",
      "title": "OIDC workload identity",
      "description": "Authenticate gRPC callers with short-lived OIDC/OAuth 2.0 tokens issued by the approved enterprise provider.",
      "advantages": ["Standards-based claims", "Works with ASP.NET Core authorization"],
      "disadvantages": ["Requires provider and client registration"],
      "consequences": ["Clients obtain and attach tokens", "Server validates issuer and audience"],
      "grpcCentered": true
    }
  ],
  "selectedOptionId": null,
  "decision": null,
  "rationale": null,
  "unresolvedReason": "Deferred to Platform Security before the pilot design review.",
  "nextAction": "Platform Security selects the approved workload identity flow and reviewer.",
  "owner": { "state": "known", "value": "Platform Security" },
  "affectedIds": ["END-order-nettcp", "SVC-order-service"],
  "riskIds": ["RSK-order-windows-auth"],
  "evidenceIds": ["EVD-order-windows-auth"],
  "approvals": [],
  "supersededBy": null
}
```

### Proposed decision

```json
{
  "id": "DEC-order-service-target-runtime",
  "title": "Select the target .NET runtime",
  "category": "target-runtime",
  "state": "proposed",
  "questionIds": ["QST-order-service-target-runtime"],
  "context": "Target runtime is a future-state choice and must be confirmed for every migration.",
  "options": [
    {
      "id": "OPT-order-service-runtime-net10",
      "title": ".NET 10 LTS",
      "description": "Host the gRPC service on ASP.NET Core using .NET 10 LTS.",
      "advantages": ["Current LTS support window", "Full ASP.NET Core gRPC support"],
      "disadvantages": ["May require upgrading deployment images and libraries"],
      "consequences": ["Build and deployment baselines move to .NET 10"],
      "grpcCentered": true
    }
  ],
  "selectedOptionId": "OPT-order-service-runtime-net10",
  "decision": "Target .NET 10 LTS for the ASP.NET Core gRPC host.",
  "rationale": "The platform owner selected the current LTS and no inventory constraint requires an older supported runtime.",
  "unresolvedReason": null,
  "nextAction": "Request architecture review approval.",
  "owner": { "state": "known", "value": "Platform Engineering" },
  "affectedIds": ["SVC-order-service"],
  "riskIds": [],
  "evidenceIds": ["EVD-user-target-runtime"],
  "approvals": [],
  "supersededBy": null
}
```

## 11. Validation checklist

Before each persisted update:

- parse JSON and validate against Draft 2020-12 schemas;
- verify every referenced `QST-*`, `RSK-*`, affected ID, and inventory
  evidence ID exists or is a documented interview-owned question;
- verify every selected option exists and is gRPC-centered;
- verify unresolved/proposed/approved/rejected/superseded invariants;
- verify approved decisions have approved `APV-*` entries;
- verify no duplicate IDs or array members;
- verify no secret-like values were persisted;
- verify the inventory ID and source basis are current;
- verify local Markdown links in the skill package resolve.

