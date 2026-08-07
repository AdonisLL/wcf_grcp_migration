# Orchestrator Handoff Contract

The `wcf-migration-orchestrator` agent
([`../../../agents/wcf-migration-orchestrator.agent.md`](../../../agents/wcf-migration-orchestrator.agent.md))
coordinates this stage. The same contract applies when a user invokes the
architect directly, so both callers get identical discipline.

Scope: the interface between the caller (orchestrator, another agent, or a user)
and the specification stage — `grpc-migration-architect` running
[`../SKILL.md`](../SKILL.md). It is a documented message contract, not a
checked-in JSON Schema; the artifacts it points at are schema-validated.

## Preconditions the caller must satisfy

1. Inventory exists, validates against
   [`inventory.schema.json`](../../../schemas/inventory.schema.json), and covers
   the declared scope.
2. Decision log exists and validates against
   [`decision-log.schema.json`](../../../schemas/decision-log.schema.json).
3. `mapping-result.json` exists, validates against
   [`mapping-result.schema.json`](../../../schemas/mapping-result.schema.json),
   and includes every unsupported-feature risk.
   Proposed decisions are valid draft inputs; unresolved immediate blockers
   may leave only their affected surfaces incomplete.
4. The output directory is writable and contains any prior artifacts for this
   repository.

If a precondition fails, the stage returns `status: blocked` with
`blockingItems[].kind: "missing-input"` and does not write artifacts.

## Inbound request

```json
{
  "stage": "author-migration-specs",
  "repositoryRoot": ".",
  "scope": { "includeServiceIds": ["SVC-order-service"], "excludeServiceIds": [] },
  "outputDirectory": "docs/wcf-grpc-migration",
  "inputs": {
    "inventoryPath": "docs/wcf-grpc-migration/inventory.json",
    "decisionLogPath": "docs/wcf-grpc-migration/decision-log.json",
    "mappingResultPath": "docs/wcf-grpc-migration/mapping-result.json"
  },
  "mode": "full",
  "approvalIntent": "request-review",
  "humanApproval": null,
  "constraints": {
    "allowNetwork": false,
    "maxParallelWorkPackages": 4
  }
}
```

- `mode` is `full` or `incremental`; both preserve stable IDs, field numbers,
  reservations, and approvals.
- `approvalIntent` is `none`, `request-review`, or `record-human-approval`.
  `request-review` writes `migration-review.json` and
  `migration-review.md` with an exact semantic digest and approval scope.
  `record-human-approval` requires `humanApproval` with the exact current
  `reviewBundleDigest`, `approvedDecisionIds`, `approvedArtifactId`,
  `approvedWorkPackageIds`,
  `reviewerIdentity`, `approvedAt`, and direct `statement`. The stage verifies
  those values and persists the human approval without regenerating semantic
  content. Artifact and work-package approval records carry the same
  `reviewBundleDigest`. It never chooses or infers approval.
- Unknown or omitted fields fall back to the documented defaults
  (`outputDirectory` = `docs/wcf-grpc-migration`, `mode` = `full`,
  `approvalIntent` = `none`, `humanApproval` = `null`, full repository scope).
  State assumed defaults in the response.

## Outbound response

```json
{
  "stage": "author-migration-specs",
  "status": "blocked",
  "artifacts": [
    { "path": "docs/wcf-grpc-migration/migration-spec.json", "artifactId": "MSPEC-contoso-orders", "approval": "draft", "sourceDigest": "sha256:<64 hex>", "semanticDigest": "sha256:<64 hex>", "changed": true },
    { "path": "docs/wcf-grpc-migration/migration-review.json", "artifactId": "MREV-contoso-orders", "approval": "review-requested", "sourceDigest": "sha256:<64 hex>", "semanticDigest": "sha256:<64 hex>", "changed": true }
  ],
  "coverage": {
    "servicesInScope": 3,
    "servicesSpecified": 2,
    "architectureSectionsResolved": 13,
    "architectureSectionsTotal": 15,
    "workPackages": 11,
    "workPackagesReady": 8
  },
  "blockingItems": [
    {
      "kind": "unresolved-decision",
      "questionIds": ["QST-external-consumer-upgrade-control"],
      "decisionIds": ["DEC-consumer-cutover"],
      "riskIds": ["RSK-external-soap-consumers"],
      "blocks": ["architecture:coexistence", "SPEC-order-service", "WP-coexistence-routing"],
      "whyBlocking": "Cutover sequencing and legacy endpoint retention cannot be specified.",
      "nextAction": "Interview stage must resolve consumer upgrade control and record an approved decision."
    }
  ],
  "deferredItems": [],
  "fleetPlan": {
    "waves": [
      { "wave": 1, "parallelGroup": "foundation", "workPackageIds": ["WP-foundation-proto-conventions"], "fleetEligible": false }
    ],
    "ownershipConflicts": []
  },
  "graph": { "acyclic": true, "cycles": [] },
  "validation": [
    { "check": "migration-spec.schema.json", "result": "passed" },
    { "check": "local-markdown-links", "result": "passed" },
    { "check": "work-package-dag", "result": "passed" }
  ],
  "assumptions": ["Output directory defaulted to docs/wcf-grpc-migration."],
  "nextRequiredAction": "Resolve QST-external-consumer-upgrade-control, then re-run this stage in incremental mode."
}
```

### Status semantics

| `status` | Meaning |
|---|---|
| `complete` | Every in-scope service is drafted, all fifteen architecture sections are `proposed` or `approved`, every work package is ready, the review bundle is current, and all validations passed. Approval is still a separate human gate. |
| `partial` | Artifacts were written and are internally valid, but coverage is incomplete for a non-blocking reason (for example an out-of-scope service or a deferred, non-blocking decision). |
| `blocked` | A blocking precondition or decision prevents a required surface. Written artifacts remain valid and unapproved; the blocked surfaces stay `unresolved`. |

`blockingItems[].kind` is one of `missing-input`, `invalid-input`,
`unresolved-decision`, `stale-approval`, `analysis-gap`, `ownership-conflict`,
`dependency-cycle`, or `validation-failure`. Every entry names what it blocks and
the exact next action that unblocks it.

`deferredItems` carries non-blocking operational unknowns postponed to an
explicit implementation, validation, or cutover gate. Each has a role or owner
and a concrete next action; a named individual is required when executable
work is assigned.

## Invariants the stage guarantees

- Artifacts are written only inside `outputDirectory`; no application file is
  created, modified, or deleted.
- Re-running with unchanged inputs produces byte-identical artifacts and
  reports `changed: false`; `generatedAt` is not bumped when the source digest
  and semantics are unchanged.
- Stable IDs, Protobuf field numbers, reservations, approvals, and supersession
  history are preserved across runs.
- Semantic digests exclude approval-event metadata. A semantic change
  invalidates the review bundle; recording the exact reviewed approval does
  not.
- No decision is answered, approved, or silently retargeted away from gRPC.
- No GitHub mutation, no implementation, no validation execution, no parity
  claim.

## Downstream handoffs (data only)

| Consumer | Receives | Not permitted here |
|---|---|---|
| `publish-migration-issues` | Approved work packages and the issue-ready payload preview | Creating issues or labels; that stage is confirmation-gated |
| [`implement-grpc-migration`](../../implement-grpc-migration/SKILL.md) | Approved work packages with dependencies, ownership, deliverables, acceptance, validation, rollback, coexistence | Writing migration code |
| Validation stage ([`validate-grpc-parity`](../../validate-grpc-parity/SKILL.md)) | Acceptance criteria and `VAL-*` definitions with `status: not-run` | Executing tests or marking `passed` |
| Interview stage | `blockingItems` with the `QST-*`/`DEC-*` that must be resolved | Answering them |

## Direct user invocation

Treat the user's request as the request envelope, state the defaults you
assumed, and return the response envelope rendered as a short readable summary:
artifacts written, coverage, blocking items with next actions, fleet waves,
ownership conflicts, validation results, and the next required human action.
