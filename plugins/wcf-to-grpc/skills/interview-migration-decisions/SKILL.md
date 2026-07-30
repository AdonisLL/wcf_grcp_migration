---
name: interview-migration-decisions
description: >
  Conducts an evidence-driven WCF-to-gRPC architecture interview from a
  validated inventory. Asks only migration decisions that code and
  configuration cannot establish, explains each evidence trigger and
  consequence, recommends a gRPC-centered option when justified, and
  incrementally persists stable, traceable decisions conforming to
  schemas/decision-log.schema.json.
---

# Skill: Interview Migration Decisions

## Purpose

Turn an evidence-backed WCF inventory into an explicit, reviewable decision
log for a migration whose mandatory destination is **gRPC on ASP.NET Core**.
The interview closes business, architecture, operational, and rollout choices
that static analysis cannot establish confidently. It does not repeat
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

- **gRPC is mandatory.** Every final option keeps gRPC on ASP.NET Core as the
  service migration target. A broker, cache, gateway, SOAP adapter, JSON
  transcoding surface, saga coordinator, or similar technology may appear
  only as an explicitly approved supporting redesign component. It must not
  replace gRPC as the target. A coexistence bridge needs exit criteria.
- **Ask decisions, not discoverable facts.** Do not ask the user for a
  framework, binding, endpoint, timeout, contract shape, security setting, or
  consumer that code/configuration can establish. Return missing
  repository-discoverable facts as inventory-analysis gaps instead.
- **Ask the target runtime every migration.** Even when repository evidence
  suggests a target, ask for confirmation because it is a future-state
  decision. Recommend the current supported .NET LTS after checking the
  current support policy; as of 2026-07-30 that is .NET 10 LTS.
- **One focused question at a time.** Ask a single atomic architectural
  choice, wait for its answer, persist it, then rebuild and reprioritize the
  queue. Combine subparts only when they cannot be decided independently.
- **Evidence before prompt.** State why the choice matters, the precise
  `EVD-*`, `RSK-*`, `QST-*`, and affected inventory IDs that triggered it,
  and what downstream design is blocked.
- **Recommend without pretending certainty.** Offer one recommended option
  only when inventory evidence and the mapping references justify it. State
  assumptions and trade-offs. Never auto-select or auto-approve it.
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

## Interview preparation

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

Prioritize in this order, then re-run priority after every answer:

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

## Question interaction

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

Do not dump the full catalog or ask a questionnaire batch. The user may:

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

- A user answer is not automatically approval. It creates or updates a
  `proposed` decision.
- Move a decision to `approved` only after an explicit approval statement
  identifies the reviewer/role. Add an `APV-*` event and sanitized citation.
- High-risk supporting redesign components require explicit approval,
  including their role, owner, operational consequence, and exit condition
  when temporary.
- Keep the decision-log artifact `draft` while any blocking decision is
  unresolved, stale, or merely proposed.
- Request artifact review only when all blocking decisions are approved and
  all non-blocking deferrals have owners and next actions.
- The containing artifact and its decisions require separate approval. Do not
  treat one as approval of the other.
- WCF retirement and cutover require their own approval; architecture approval
  does not authorize production cutover.

## Completion criteria

The interview is ready for handoff only when:

- [ ] the input inventory validates and analysis gaps are reported separately;
- [ ] target runtime was asked for this migration and the current .NET LTS was
      recommended unless constraints justify another supported runtime;
- [ ] every triggered catalog topic is answered, deferred, unresolved,
      skipped by evidence, or made irrelevant by an approved parent decision;
- [ ] no repository-discoverable fact was unnecessarily asked;
- [ ] each prompt showed why it mattered and its evidence trigger;
- [ ] all high/critical unsupported WCF features have explicit decisions or
      blocking unresolved entries;
- [ ] gRPC remains the target in every proposed/approved option;
- [ ] all answers, unresolved items, and deferrals conform to
      `decision-log.schema.json`;
- [ ] stable IDs, approvals, citations, and trace links were preserved;
- [ ] stale decisions are revalidated or block progression;
- [ ] no secrets were requested or persisted;
- [ ] `decision-log.json` validates against the checked-in Draft 2020-12
      schema;
- [ ] every local Markdown link in this skill and its references resolves.

## Outputs

1. Updated `decision-log.json`.
2. A concise interview status summary:
   - approved, proposed, unresolved, deferred, and stale counts;
   - next highest-priority question or “interview complete”;
   - inventory-analysis gaps;
   - blocking approval gates.
3. No architect agent, migration specification, issues, or implementation.

