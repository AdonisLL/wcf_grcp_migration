# Publication Handoff Contract

This skill is a documented request/response contract for the future publication
stage. It is not an executable schema; the generated artifacts remain validated
by [`../../../schemas/issue-set.schema.json`](../../../schemas/issue-set.schema.json).

## Preconditions

1. `migration-spec.json` exists, validates, and the artifact approval is
   `approved`.
2. Every in-scope work package intended for publication is individually
   approved.
3. The target repository is known as `owner/repo`.
4. Any existing `issue-set.json` validates.
5. The output directory is writable.
6. For mutation modes only, existing GitHub authentication is already present in
   the environment.

If a precondition fails, return `status: blocked`, report the exact IDs or
paths, and do not mutate GitHub.

## Inbound request

```json
{
  "stage": "publish-migration-issues",
  "repositoryRoot": ".",
  "outputDirectory": "docs/wcf-grpc-migration",
  "inputs": {
    "migrationSpecPath": "docs/wcf-grpc-migration/migration-spec.json",
    "issueSetPath": "docs/wcf-grpc-migration/issue-set.json"
  },
  "targetRepository": "contoso/orders-migration",
  "scope": {
    "includeWorkPackageIds": ["WP-foundation-proto-conventions"],
    "excludeWorkPackageIds": []
  },
  "mode": "dry-run",
  "confirmation": null,
  "allowFallbackGhCli": false
}
```

### Field semantics

- `mode` is one of:
  - `dry-run` - generate preview only;
  - `export-only` - generate preview and persist artifacts only;
  - `publish-approved` - publish only when `confirmation` is present and matches
    the current preview digest.
- `scope` defaults to all approved work packages in the specification.
- `issueSetPath` is optional; when omitted, use
  `docs/wcf-grpc-migration/issue-set.json`.
- `allowFallbackGhCli` defaults to `false`. When `true`, GitHub CLI mutation is
  allowed only after GitHub read/search preflight and only if no approved write
  tool is available.

## Confirmation payload

Mutation requires an explicit confirmation object:

```json
{
  "previewDigest": "sha256:<64 hex>",
  "approvedBy": "release-manager",
  "approvedAt": "2026-07-30T16:00:00Z",
  "allowLabelCreation": true,
  "allowIssueCreation": true,
  "allowDependencyPatch": true
}
```

Every field is mandatory for `publish-approved`. Missing permission flags block
mutation rather than defaulting to `true`.

## Outbound response

```json
{
  "stage": "publish-migration-issues",
  "status": "previewed",
  "artifacts": [
    {
      "path": "docs/wcf-grpc-migration/issue-set.json",
      "artifactId": "ISET-contoso-orders",
      "changed": true,
      "previewDigest": "sha256:<64 hex>"
    }
  ],
  "counts": {
    "approvedWorkPackages": 4,
    "issuesRendered": 4,
    "issuesPublished": 1,
    "issuesReady": 3,
    "labelsPlanned": 5,
    "labelsCreated": 0
  },
  "publishOrder": [
    "ISSUE-foundation-proto-conventions",
    "ISSUE-foundation-host-bootstrap",
    "ISSUE-order-service-contract",
    "ISSUE-order-service-server"
  ],
  "duplicateFindings": [
    {
      "issueId": "ISSUE-foundation-proto-conventions",
      "result": "already-published",
      "githubUrl": "https://github.com/contoso/orders-migration/issues/101"
    }
  ],
  "blockingItems": [],
  "errors": [],
  "nextRequiredAction": "Confirm preview digest sha256:<64 hex> to allow label and issue publication."
}
```

## Status semantics

| Status | Meaning |
|---|---|
| `previewed` | Preview artifacts were regenerated and no GitHub mutation occurred. |
| `completed` | Labels, issues, and dependency-link patches all succeeded. |
| `blocked` | Input, validation, duplicate, auth, permission, or rate-limit failure prevented safe progress. |
| `partial-failure` | Some mutations succeeded and were persisted, but the publication could not finish safely. |
| `declined` | A reviewer explicitly declined the preview. |

## Required blocking kinds

Use specific blocking kinds so reruns know what changed:

- `invalid-input`
- `unapproved-work-package`
- `missing-confirmation`
- `stale-preview-digest`
- `duplicate-conflict`
- `auth-missing`
- `permission-denied`
- `rate-limited`
- `dependency-cycle`
- `dependency-patch-failed`
- `validation-failure`

## Invariants

- Every approved work package in scope appears in the preview.
- No label or issue mutation happens before explicit confirmation.
- Labels are created only after confirmation.
- Issues are created in dependency-safe order.
- Dependency links are patched only after issue numbers are known.
- Partial successes are persisted so reruns are resumable.
- No secrets are collected, transformed, or stored.
- Errors are reported verbatim; success is reported only when the final state is
  actually complete.
