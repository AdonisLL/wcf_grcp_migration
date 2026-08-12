# WCF-to-gRPC code handoff

## Code completion

- **Status:** code-complete
- **Source revision:** git:0123456789abcdef
- **WCF state:** Active and unchanged
- **Solution layout:** augment-existing-solution
- **gRPC root:** `.`
- **WCF source handling:** retain-in-place

## Delivered code

- `src/Contoso.Orders.Grpc/Contoso.Orders.Grpc.csproj`

## Repository-local validation

- `VAL-final-build` — passed

## Code gaps and deviations

None.

## Offline obligations

Every obligation is `not-executed`.

| ID | Category | Next action |
|---|---|---|
| OBL-environment-configuration | environment-configuration | Map documented configuration keys for each target environment. |
| OBL-secrets | secrets | Create secret-store bindings for the documented configuration references. |
| OBL-deployment | deployment | Author and review deployment changes outside this plugin. |
| OBL-service-discovery | service-discovery | Choose and configure the environment-specific endpoint registration. |
| OBL-identity-tls | identity-and-tls | Bind the approved identity and certificate references. |
| OBL-data-state | data-and-state | Exercise state consistency and recovery in the target environment. |
| OBL-external-dependencies | external-dependencies | Run environment connectivity checks with each external owner. |
| OBL-observability | observability-health-capacity | Verify health, traces, metrics, logs, load limits, and alerts after deployment. |
| OBL-environment-parity | environment-parity-validation | Run independent environment validation before any cutover decision. |
| OBL-consumer-cutover | consumer-cutover | Create an offline consumer rollout and traffic-change plan. |
| OBL-live-rollback | live-rollback | Approve and rehearse the live rollback runbook outside this plugin. |
| OBL-wcf-retirement | wcf-retirement | Evaluate retirement separately after cutover stability and rollback retention requirements are met. |

Code completion is not deployment readiness, runtime parity, cutover
authorization, live rollback completion, or WCF retirement authorization.
