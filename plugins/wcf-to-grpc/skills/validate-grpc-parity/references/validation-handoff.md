# Validation Handoff Contract

The interface between a human operator invoking optional post-workflow
validation and `grpc-parity-validator` running [`../SKILL.md`](../SKILL.md).
The code-only orchestrator never uses this contract. It
mirrors the discipline of the architecture stage's
[`orchestrator-handoff.md`](../../author-migration-specs/references/orchestrator-handoff.md)
and the implementation stage's
[`handoff-report-contract.md`](../../implement-grpc-migration/references/handoff-report-contract.md).

This is a documented message contract, not a checked-in JSON Schema; the
upstream artifacts it points at are schema-validated.

## Preconditions the caller must satisfy

1. `code-handoff.json` exists, validates against
   [`code-handoff.schema.json`](../../../schemas/code-handoff.schema.json), and
   names the revision deployed for this manual validation.
2. `migration-spec.json` exists, validates against
   [`migration-spec.schema.json`](../../../schemas/migration-spec.schema.json),
   and its architecture and contract surfaces for the scope are `approved`.
3. `inventory.json` and `decision-log.json` exist for the same repository and
   cover the scope, so a legacy baseline is available.
4. The in-scope work packages have implementation reports (`completed` or
   `partial`) under
   `docs/wcf-grpc-migration/implementation-reports/`.
5. For behavioral gates, a runnable environment is reachable, and the caller
   states which environment it is.
6. Any golden-traffic permission is already recorded per
   [`golden-traffic-and-safety.md`](golden-traffic-and-safety.md).

If a precondition fails, the stage returns `status: blocked`, writes a report
containing only `blocked` gate results, and changes nothing else.

## Inbound request

```json
{
  "stage": "validate-grpc-parity",
  "repositoryRoot": ".",
  "outputDirectory": "docs/wcf-grpc-migration",
  "inputs": {
    "codeHandoffPath": "docs/wcf-grpc-migration/code-handoff.json",
    "migrationSpecPath": "docs/wcf-grpc-migration/migration-spec.json",
    "inventoryPath": "docs/wcf-grpc-migration/inventory.json",
    "decisionLogPath": "docs/wcf-grpc-migration/decision-log.json",
    "implementationReportsPath": "docs/wcf-grpc-migration/implementation-reports"
  },
  "scope": {
    "workPackageIds": ["WP-order-service-server"],
    "serviceIds": [],
    "gates": "all"
  },
  "intent": "gate",
  "environment": {
    "name": "integration",
    "productionEquivalent": false,
    "grpcEndpoint": "configured-by-operator",
    "legacyWcfEndpoint": "configured-by-operator"
  },
  "permissions": {
    "allowNetwork": true,
    "allowHarness": true,
    "allowGoldenTraffic": false,
    "allowLoadTest": false,
    "allowProductionAccess": false
  }
}
```

- `intent` is `gate` (assess the assigned scope) or `retirement` (also
  assess checklist gate 13 per
  [`retirement-gate.md`](retirement-gate.md)).
- `scope.gates` is `all` or an explicit list of gate slugs; gates outside it
  are reported `not-assessed` with the reason.
- Endpoint values are supplied by the operator's environment or
  configuration — never a credential, never a secret.
- Unknown or omitted fields fall back to the documented defaults
  (`outputDirectory` = `docs/wcf-grpc-migration`, `intent` = `gate`,
  `scope.gates` = `all`, every permission = `false`). State assumed defaults
  in the response.

## Outbound response

```json
{
  "stage": "validate-grpc-parity",
  "status": "fail",
  "reportId": "VRPT-order-service-server",
  "scopeKey": "wp-order-service-server",
  "artifacts": [
    { "path": "docs/wcf-grpc-migration/validation-reports/wp-order-service-server.md", "kind": "validation-report" },
    { "path": "docs/wcf-grpc-migration/validation-reports/wp-order-service-server.checklist.md", "kind": "parity-checklist" }
  ],
  "gates": [
    { "gate": "contract-parity", "state": "pass", "checksRequired": 8, "checksPassed": 8 },
    { "gate": "error-parity", "state": "fail", "checksRequired": 6, "checksPassed": 5 },
    { "gate": "performance-and-limits", "state": "blocked", "reason": "No agreed latency SLA recorded." }
  ],
  "findings": [
    {
      "id": "VF-error-parity-validation-fault-maps-to-unknown",
      "gate": "error-parity",
      "severity": "blocking",
      "confidence": "high",
      "status": "open",
      "affectedIds": ["OP-order-submit", "RPC-order-submit", "AC-order-fault-mapping"],
      "evidenceIds": ["EVD-order-submit-invalid-quantity-status"],
      "remediation": "Map ValidationFault to INVALID_ARGUMENT with the specified detail message.",
      "owner": "WP-order-service-server",
      "nextAction": "Implementation stage re-runs WP-order-service-server for the error-mapping deliverable."
    }
  ],
  "coverage": {
    "operationsInScope": 12,
    "operationsExercised": 12,
    "gatesApplicable": 12,
    "gatesPassed": 10,
    "acceptanceCriteriaVerified": 9,
    "acceptanceCriteriaMet": 8
  },
  "retirement": { "assessed": false },
  "assumptions": ["Output directory defaulted to docs/wcf-grpc-migration."],
  "nextRequiredAction": "Remediate VF-error-parity-validation-fault-maps-to-unknown, then re-run this stage for the same scope."
}
```

For an `intent: retirement` run, `retirement` carries the outcome:

```json
{
  "retirement": {
    "assessed": true,
    "outcome": "retirement-not-ready",
    "unmetConditions": ["consumer-unknown-callers", "rollback-not-rehearsed"],
    "assessmentPath": "docs/wcf-grpc-migration/validation-reports/retirement-readiness.md"
  }
}
```

## Status semantics

| `status` | Meaning |
|---|---|
| `pass` | Every applicable gate is `pass` or `not-applicable`; no finding is open. Scope-limited: it certifies the assessed scope only. |
| `conditional-pass` | Every applicable gate is `pass` or `not-applicable`; no blocking finding is open; one or more non-blocking findings are open, each with an owner and next action. |
| `fail` | An applicable gate is `fail`, or a blocking finding is open. |
| `blocked` | An applicable gate could not be assessed (missing input, missing environment, missing baseline, missing permission). Parity is unknown, which is never reported as success. |

Computation rules are normative in
[`evidence-and-findings.md`](evidence-and-findings.md#5-run-status-computation).

## Invariants this stage guarantees

- No application source, `.proto` file, project/build file, product test,
  deployment manifest, or configuration file is created, modified, or
  deleted.
- `inventory.json`, `decision-log.json`, `migration-spec.json`,
  `issue-set.json`, and implementation reports are never edited.
- All writes are inside `outputDirectory`, at paths deterministic from the
  scope key, so parallel runs never collide.
- No gate is reported `pass` without executed evidence at the confidence its
  gate requires; no behavioral gate is passed on static analysis, a green
  build, or an implementer's claim.
- No secret value, raw credential, or unmasked personal data is written to
  any artifact.
- No approval state is set anywhere; retirement is assessed, never granted.
- Re-running with unchanged inputs and unchanged evidence reproduces the
  same ids and the same gate results.

## Downstream consumers

| Consumer | Receives | Not permitted here |
|---|---|---|
| Human caller | `status`, gate matrix, findings, `nextRequiredAction` for offline remediation or operational planning | This validator does not dispatch work packages or alter orchestration state |
| [`implement-grpc-migration`](../../implement-grpc-migration/SKILL.md) | Blocking/non-blocking findings with owners, as remediation input for the named work package | This stage never implements the fix |
| [`author-migration-specs`](../../author-migration-specs/SKILL.md) | Findings whose remediation is a specification or decision change | This stage never edits the spec |
| Interview stage | Findings that reveal an unresolved decision (`QST-*`/`DEC-*` needed) | This stage never answers a decision |
| Human retirement approver | The retirement-readiness assessment and its evidence | This stage never records the approval |

## Direct user invocation

Treat the user's request as the request envelope, state the defaults and
permissions you assumed (all permissions default to `false`), and return the
response envelope as a short readable summary: scope, gate matrix, blocking
findings first, non-blocking findings, evidence highlights, run status, and
the next required human action.
