# Migration review: MREV-example-orders

**Semantic digest:** `sha256:6666666666666666666666666666666666666666666666666666666666666666`
**Digest algorithm:** `sha256-rfc8785-v1`
**Approval state:** `review-requested`

## Recommended decisions

### DEC-target-runtime — agent-proposed

Host the gRPC service on the current supported .NET LTS.

## Digest-bound review artifacts

| Kind | Artifact | Content digest | Bound IDs |
|---|---|---|---|
| architecture | `target-architecture.md` | `sha256:7777777777777777777777777777777777777777777777777777777777777777` | DEC-target-runtime |
| contract | `contracts/SPEC-orders.md` | `sha256:8888888888888888888888888888888888888888888888888888888888888888` | SPEC-orders |
| roadmap | `roadmap.md` | `sha256:9999999999999999999999999999999999999999999999999999999999999999` | PHS-foundation, WP-orders-server, WP-integration-verification |
| work-package | `work-packages/WP-orders-server.md` | `sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa` | WP-orders-server |
| work-package | `work-packages/WP-integration-verification.md` | `sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb` | WP-integration-verification |

## Immediate blockers

None.

## Offline handoff items

- DEC-sla-objectives — gate `offline-handoff`
- DEC-deployment-environment-progression — gate `offline-handoff`
- DEC-cutover-gates — gate `offline-handoff`

## Approval scope

- Decisions: DEC-target-runtime
- Work packages: WP-orders-server, WP-integration-verification
