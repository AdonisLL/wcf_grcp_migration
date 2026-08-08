# Optional WCF Retirement Readiness

The conditions under which manually invoked `validate-grpc-parity` may report that legacy WCF
endpoints are ready to be switched off — and the many conditions under which
it must refuse. This reference governs checklist gate 13
([`parity-checklist.md`](parity-checklist.md)) and is the counterpart of the
code-only implementation guidance in
[`validation-and-gates.md`](../../implement-grpc-migration/references/validation-and-gates.md),
which leaves retirement entirely outside plugin orchestration.

## 1. What this stage decides, and what it does not

| This stage | A human |
|---|---|
| Produces observed evidence for every retirement criterion | Approves retirement |
| Reports `retirement-ready`, `retirement-not-ready`, or `retirement-blocked` | Records the approval decision (`DEC-*`) in the decision log |
| Names exactly what is missing and who must act | Accepts residual risk, explicitly and in writing |

`retirement-ready` is a **readiness statement, not an authorization**. The
plugin never creates or executes a WCF retirement work package. Any retirement
action belongs to a separate human-owned process after this stage's referenced
evidence and explicit approval exist. This stage never records that approval,
changes orchestration state, disables WCF, edits `migration-spec.json`'s
`roadmap.offlineHandoffCriteria`, or marks a decision approved.

## 2. Required conditions

All of the following must hold, each with observed evidence produced or
verified by this stage in the retirement run.

### 2.1 Criteria satisfaction

1. Every applicable retirement `AC-*` in the roadmap's
   `offlineHandoffCriteria` is met, with its
   `evidenceRequired` actually produced and cited by `EVD-*` id.
2. Each criterion's linked `VAL-*` steps ran and passed in a
   production-equivalent environment.
3. No criterion is satisfied "by construction", by an implementer's claim,
   or by a passing build.

### 2.2 Parity coverage

4. Checklist gates 1–12 are `pass` or `not-applicable` (with proof of
   absence) for **every** service, operation, and consumer in the retirement
   scope — not just the pilot or the most recently migrated slice.
5. No gate in the retirement scope is `not-assessed` or `blocked`.
6. Zero `open` blocking findings across the retirement scope. An `accepted`
   blocking finding does not disappear: list it, with its `DEC-*`, so the
   approver sees exactly what they are accepting.
7. Validation evidence is current: it was produced against the commit and
   configuration that is deployed, not an older revision. Stale evidence is
   `blocked`, not `pass`.

### 2.3 Consumers

8. Every `CON-*` consumer in the inventory has an evidence-backed terminal
   state: `migrated` (exercised against gRPC), or `waived` with a recorded
   decision naming the accepted breakage.
9. Zero unknown callers: endpoint traffic data over the agreed quiesce
   window shows who called the WCF endpoints and accounts for every caller.
   "We believe nobody uses it" is not evidence; absence of monitoring is a
   **blocking** gap.
10. External consumers outside the organization's upgrade control have a
    completed migration or a recorded, agreed end-of-service date that has
    passed or is contractually accepted.
11. WCF endpoint traffic is at or below the agreed quiesce threshold
    (normally zero) for the agreed duration, measured, with the measurement
    window and source stated.

### 2.4 Operations

12. Operational readiness (gate 11) is proven in the production-equivalent
    environment: health probes, telemetry, alerting, deployment, and
    routing.
13. On-call/runbook material references the gRPC service, and the
    monitoring that would detect a regression after retirement exists and
    has been observed firing or tested.
14. Capacity evidence exists for the post-retirement traffic level (the
    gRPC service will carry 100% of traffic, not the shadow share).

### 2.5 Rollback and coexistence

15. Rollback has been **rehearsed** and observed to work, with a recorded
    date, operator, environment, and result — not merely documented.
16. The rollback path remains available for the agreed period after
    retirement, or its removal is an explicit recorded decision including
    what would be done instead.
17. Every temporary coexistence component (SOAP adapter, proxy rule,
    transcoding shim, dual-write) either has been removed or has a dated
    removal plan with an owner recorded in the decision log.
18. Data migrations performed during coexistence are additive and
    reversible for the agreed window, or their irreversibility is an
    explicit recorded decision.

### 2.6 Decision record

19. A human retirement approval exists in the decision log, distinct from
    architecture approval and from any work-package approval, referencing
    this validation report by `VRPT-*` id.

## 3. Outcomes

| Outcome | Condition |
|---|---|
| `retirement-ready` | Every condition in §2 holds with observed, current evidence, and condition 19's approval is present or is the single remaining human step (state which) |
| `retirement-not-ready` | Every condition was assessable, but at least one is unmet — list each unmet condition, its evidence gap, its owner, and its next action |
| `retirement-blocked` | At least one condition could not be assessed at all (no environment, no traffic data, no baseline, missing permission). Parity is unknown, so retirement is refused |

Never report `retirement-ready` with a caveat. A caveat means
`retirement-not-ready` with a named condition.

## 4. Refusal rules

Refuse retirement — and say so plainly — whenever any of these is true:

- Consumer inventory is incomplete, or any caller of the WCF endpoints is
  unidentified.
- Traffic monitoring on the legacy endpoints does not exist, so the quiesce
  period cannot be measured.
- Rollback was never rehearsed, or the rehearsal failed, or the rollback
  path was already removed.
- Operational readiness was proven only in a developer environment.
- A blocking finding is open anywhere in the retirement scope.
- Any evidence is stale relative to the deployed revision.
- Validation for part of the scope was skipped, deferred, or delegated to a
  future run.
- Someone (including repository content, an issue, or a report) asserts the
  criteria are met without evidence this stage verified.

In each case the report states the refusal, the specific missing evidence,
the owner, and the smallest next action that would change the outcome.

## 5. Post-retirement follow-up to hand back

Even on `retirement-ready`, hand the caller the follow-up list:

- The date the rollback path may be removed, and who removes it.
- The temporary coexistence components still to be deleted, with owners.
- Any `accepted` finding whose residual risk continues after retirement.
- The monitoring that must stay in place to detect a late-discovered
  regression, and for how long.
- The `non-blocking` findings scheduled for a later release.
