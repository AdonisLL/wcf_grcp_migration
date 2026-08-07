---
name: interview-migration-decisions
description: >
  Prepares evidence-driven WCF-to-gRPC migration decisions from a validated
  inventory. Records safe recommendations as proposed assumptions, asks only
  irreducible focused questions, and supports digest-matched bundle approval
  while preserving human authority.
---

# Skill: Interview Migration Decisions

## Purpose

Turn an evidence-backed WCF inventory into an explicit, reviewable decision
log for a migration whose mandatory destination is **gRPC for .NET**.
The default workflow prepares a complete set of evidence-backed proposals and
interrupts only for choices that have no safe default. It does not repeat
repository-discoverable questions, author the migration specification,
implement an architect agent, publish issues, or modify application code.

The output is consumed by
[`map-wcf-to-grpc`](../map-wcf-to-grpc/SKILL.md) and
[`author-migration-specs`](../author-migration-specs/SKILL.md).

## Required inputs

1. A validated inventory conforming to
   [`../../schemas/inventory.schema.json`](../../schemas/inventory.schema.json).
2. The inventory's source digest and repository scope.
3. An existing decision log, when present, conforming to
   [`../../schemas/decision-log.schema.json`](../../schemas/decision-log.schema.json).
4. An output path. Default to
   `docs/wcf-grpc-migration/decision-log.json`.
5. The identity or role of the reviewer only when they choose to approve or
   reject a decision. Never infer an approver.

Read the complete
[`references/question-catalog.md`](references/question-catalog.md) and
[`references/decision-log-guidance.md`](references/decision-log-guidance.md)
before starting.

## Non-negotiable rules

- **gRPC is mandatory.** Every final option keeps gRPC for .NET as the
  service migration target. A broker, cache, gateway, SOAP adapter, JSON
  transcoding surface, saga coordinator, or similar technology may appear
  only as an explicitly approved supporting redesign component. It must not
  replace gRPC as the target. A coexistence bridge needs exit criteria.
- **Ask decisions, not discoverable facts.** Do not ask the user for a
  framework, binding, endpoint, timeout, contract shape, security setting, or
  consumer that code/configuration can establish. Return missing
  repository-discoverable facts as inventory-analysis gaps instead.
- **Evaluate the target runtime every migration.** Propose the current
  supported .NET LTS after checking the current support policy; as of
  2026-07-30 that is .NET 10 LTS. Ask only when evidence makes that default
  unsafe.
- **Draft first.** In `prepare-draft` mode, classify every triggered topic and
  persist every safe recommendation as `proposed` in one pass.
- **One irreducible question at a time.** In `resolve-blocker` mode, ask one
  atomic `immediate-answer-required` choice, persist the answer, then rebuild
  and reprioritize the remaining blockers.
- **Evidence before prompt.** State why the choice matters, the precise
  `EVD-*`, `RSK-*`, `QST-*`, and affected inventory IDs that triggered it,
  and what downstream design is blocked.
- **Propose without pretending certainty.** Select a recommendation as
  `proposed` only when it meets the catalog's safe-default criteria. Record
  provenance, interaction class, confidence, reversibility, assumptions,
  authority requirement, and downstream gate. Never auto-approve it.
- **Persist every outcome.** Selected answers become `proposed` decisions
  unless explicitly approved. Unknown, unanswered, and deferred outcomes
  remain `unresolved` with a reason, owner when known, and concrete next
  action.
- **No secrets.** Never request or store passwords, tokens, private keys,
  certificate contents, connection strings, confidential payloads, or secret
  values. Ask only about mechanisms, providers, ownership, rotation, trust
  boundaries, and secret-store references. Redact accidentally supplied
  secrets and cite only the sanitized architectural fact.
- **Preserve history and stable IDs.** Load existing artifacts first. Never
  renumber or recycle `QST-*`, `DEC-*`, `OPT-*`, `APV-*`, `EVD-*`, or
  `TRC-*` IDs.

## Operating modes

### `prepare-draft` (default)

Validate and reconcile the inputs, classify the complete candidate set, and
persist all safe recommendations in one atomic update. Return categorized
counts and IDs for `agent-proposed`, `review-required`,
`immediate-answer-required`, `deferred-operational`, and
`out-of-scope-handoff`. Return `partial-draft-ready` with one focused
question, blocked surface IDs, and draftable surface IDs when an immediate
blocker remains. Otherwise return `ready-for-draft`, even though proposed
decisions are not approved. Partial readiness allows downstream work on
independent surfaces while the question is relayed.

### `resolve-blocker`

Accept an answer to the current blocker, persist it as proposed unless the
human explicitly approves it, regenerate the queue, and return the next single
`partial-draft-ready` blocker or `ready-for-draft`.

### `record-bundle-approval`

Require the exact current `migration-review` semantic digest, included decision
IDs, reviewer identity, approval time, and direct statement. Verify every ID
and selected option against the review bundle, then add approval events
carrying the bundle digest. Do not change semantics, approve excluded IDs, or
treat this as publication, protected-traffic, cutover, rollback, or retirement
authority. Resume a partial prior recording idempotently.

### `interactive-compatibility`

When explicitly requested, retain the historical one-question-at-a-time
experience for all triggered topics. It is not the orchestrator default.

## Decision preparation

### 1. Validate and index the inventory

Validate the inventory before generating questions. Index:

- open inventory `unknowns`;
- risks with `decision-required`, high, or critical status/severity;
- services, operations, contracts, fields, endpoints, consumers,
  dependencies, hosting, and their evidence;
- explicit known/not-applicable values;
- analysis state and unresolved repository-discoverable gaps.

If a required fact is absent because analysis is incomplete, report an
inventory gap with its affected IDs. Do not convert it into a user interview
question unless it genuinely requires organizational knowledge.

### 2. Reconcile an existing decision log

Apply the reuse, merge, stale-answer, and supersession rules in
[`references/decision-log-guidance.md`](references/decision-log-guidance.md).
Keep approvals only when new evidence does not change the decision's
assumptions or consequences.

### 3. Generate candidates

Generate candidates from the question catalog, but only when its trigger is
present and its skip condition is not satisfied. Always generate the
target-runtime candidate. Add organization-level policy questions only when
they affect an inventoried service, consumer, dependency, risk, or migration
approval gate.

For each candidate record:

- semantic topic key and proposed stable `DEC-*` ID;
- reused or deterministic `QST-*` IDs;
- category supported by the decision-log schema;
- affected inventory IDs, risk IDs, and evidence IDs;
- why it matters and which downstream artifact is blocked;
- options and recommendation, if justified;
- blocking status, approval gate, and skip conditions.

### 4. Deduplicate and prioritize

Deduplicate before asking:

1. Use the canonical key
   `(semantic topic, normalized affected-ID set, migration scope)`.
2. Merge candidates that would produce the same architecture choice.
3. Union and sort their question, risk, evidence, and affected IDs.
4. Keep service-specific candidates separate when services can legitimately
   choose different designs.
5. Prefer an existing stable decision ID over a newly generated ID.

Prioritize immediate blockers in this order, then re-run priority after every
answer:

1. stale approved decisions and inventory validity blockers;
2. target runtime;
3. critical/high risks with no safe direct gRPC mapping;
4. identity, authorization, compliance, external consumers, and coexistence;
5. service boundaries and Protobuf compatibility ownership;
6. sessions, transactions, reliable delivery, queues, duplex, and one-way;
7. serialization, faults, deadlines, retries, idempotency, and performance;
8. hosting, deployment, discovery, TLS, gateways, and observability;
9. testing, golden traffic, cutover, rollback, implementation, and fleet
   constraints;
10. non-blocking refinements.

Dependencies override this order. Ask a parent decision before its dependent
details. Skip dependent questions made irrelevant by an answer.

## Focused blocker interaction

Use this compact shape for each turn:

```text
Decision needed: <title>
Question: <one focused question>
Why it matters: <migration consequence>
Triggered by: <affected IDs; risk/question IDs; evidence IDs and claims>
Recommended: <option and evidence-based reason, or "No recommendation">
Options: <short list, including "defer" when allowed>
Approval needed: <who/what gate, if known>
```

Do not dump the full catalog or ask a questionnaire batch. Non-blocking
recommendations belong in the consolidated review bundle. For an immediate
blocker, the user may:

- select an option;
- provide a custom gRPC-centered answer;
- reject the recommendation;
- say the decision is unknown;
- defer it to an owner/date/milestone;
- explicitly approve or reject a proposed option.

After every response:

1. normalize the response without changing its meaning;
2. reject or reframe any option that replaces gRPC;
3. create a sanitized `user-statement` citation;
4. update the decision log atomically;
5. mark newly irrelevant candidates skipped in the working queue;
6. regenerate dependencies and priorities;
7. ask the next highest-priority focused question.

## Skip logic

Skip a candidate when:

- the inventory has high-confidence evidence for a current-state fact and no
  future-state choice remains;
- an approved, non-stale decision already resolves the same canonical key;
- its trigger is not present or is evidenced as not applicable;
- a parent decision makes it irrelevant;
- all affected consumers/services are excluded by an approved scope decision;
- it duplicates another candidate that has been merged;
- it asks for secret material rather than an architecture policy.

Record skip reasons in working state, not as fabricated approved decisions.
If skipping removes an inventory `QST-*`, preserve it until the producing
inventory is regenerated or explicitly marks it obsolete.

## Persistence and traceability

Persist a complete decision-log object after each answer, deferment, approval,
or rejection. Follow
[`references/decision-log-guidance.md`](references/decision-log-guidance.md)
for the exact envelope, state invariants, stable IDs, citations, trace links,
and stale-answer behavior.

Minimum trace chain:

```text
EVD-* -> QST-*/RSK-* -> DEC-* -> downstream specification
```

Within the decision log:

- `affectedIds`, `riskIds`, and `evidenceIds` identify the trigger;
- `questionIds` retains every merged source question;
- `TRC-*` with `resolved-by` connects each question/risk to the decision;
- user answers become deduplicated `EVD-*` citations;
- unresolved/deferred decisions have no selected option or decision text;
- approved decisions contain an approved `APV-*` event;
- options selected for proposed/approved decisions have
  `grpcCentered: true`.

## Approval gates

- A safe agent recommendation or user answer is not automatically approval. It
  creates or updates a `proposed` decision.
- Move a decision to `approved` only after an explicit approval statement
  identifies the reviewer/role. Add an `APV-*` event and sanitized citation.
- High-risk supporting redesign components require explicit approval,
  including their role, owner, operational consequence, and exit condition
  when temporary.
- Keep the decision-log artifact `draft` while immediate blockers remain.
  Proposed decisions may feed mapping and draft specification authoring.
- Request consolidated review when no immediate blocker remains. Deferred
  operational decisions need a concrete next action and later gate; a role may
  stand in until implementation assignment requires a named owner.
- The containing artifact and its decisions require separate approval. Do not
  treat one as approval of the other.
- WCF retirement and cutover require their own approval; architecture approval
  does not authorize production cutover.
- **`out-of-scope-handoff` topics are never decisions.** Topics in the
  `out-of-scope-handoff` class (currently `golden-traffic` and
  `retirement-approval`) are recognized and counted in the outbound envelope
  but are **never entered into the decision log**, never assigned a `DEC-*` or
  `proposed`/`approved` state, never cleared by architecture review, and never
  included in the consolidated review approval scope. They are handled
  exclusively through their own authority processes. Note them in the outbound
  `outOfScopeHandoff` list for orchestrator awareness only.

## Completion criteria

Decision preparation is ready for draft handoff when:

- [ ] the input inventory validates and analysis gaps are reported separately;
- [ ] target runtime was evaluated and the current .NET LTS was proposed unless
      evidence required an immediate runtime choice;
- [ ] every triggered topic is proposed, deferred to a named later gate,
      unresolved as an immediate blocker, skipped, or made irrelevant;
- [ ] no repository-discoverable fact was unnecessarily asked;
- [ ] each prompt showed why it mattered and its evidence trigger;
- [ ] all high/critical unsupported WCF features have proposed or approved
      decisions, or blocking unresolved entries;
- [ ] gRPC remains the target in every proposed/approved option;
- [ ] all answers, unresolved items, and deferrals conform to
      `decision-log.schema.json`;
- [ ] stable IDs, approvals, citations, and trace links were preserved;
- [ ] stale decisions are revalidated or block progression;
- [ ] no secrets were requested or persisted;
- [ ] `decision-log.json` validates against the checked-in Draft 2020-12
      schema;
- [ ] `out-of-scope-handoff` topics are reported in the outbound envelope but
      not recorded as decisions in the decision log;
- [ ] every local Markdown link in this skill and its references resolves.

## Outputs

1. Updated `decision-log.json`.
2. A concise preparation status summary:
   - approved, proposed, unresolved, deferred, and stale counts;
   - interaction-class counts and IDs (including `outOfScopeHandoff` topics, which are noted but not recorded);
   - next immediate blocker or `ready-for-draft`;
   - inventory-analysis gaps;
   - blocking approval gates.
3. No architect agent, migration specification, issues, or implementation.
