# Hosting, Coexistence, Rollout, and Parity Reference

> **Scope:** Guidance on hosting-topology changes when moving from WCF to
> gRPC, strategies for running WCF and gRPC side by side during transition,
> recommended rollout phases, and exit criteria for retiring WCF. The target
> is always gRPC on ASP.NET Core. Any coexistence adapter that exposes a SOAP
> or REST endpoint to legacy consumers is a temporary bridge, not a migration
> destination. See `sources.md` for citations.

---

## 1. Hosting Topology Changes

### 1.1 WCF Hosting Options

WCF services are commonly hosted:
- In **IIS / IIS Express** via `.svc` files and `web.config`.
- As a **Windows Service** via `ServiceHost` (often with a wrapper such as
  TopShelf, or registered with `sc.exe`).
- As a **self-hosted console/application** via `ServiceHost.Open()`.
- Under **COM+ / WAS** for activation-based hosting.

### 1.2 gRPC Hosting Requirements

ASP.NET Core gRPC requires:
- **ASP.NET Core** as the application host (the `Microsoft.NET.Sdk.Web` SDK,
  or a `<FrameworkReference Include="Microsoft.AspNetCore.App" />` added to a
  non-web project).
- **HTTP/2** at the transport layer (Kestrel; IIS or HTTP.sys on Windows
  Server 2022+ with .NET 5+).
- **TLS** on any Kestrel endpoint that must serve both HTTP/1.1 and HTTP/2,
  since protocol selection there depends on ALPN negotiation.

Non-ASP.NET-Core project types (Windows Services, WPF apps, console apps)
can still host a gRPC server by adding a framework reference to
`Microsoft.AspNetCore.App`.

### 1.3 Hosting Migration by WCF Topology

| WCF Hosting | gRPC Equivalent |
|---------------|--------------------|
| IIS on .NET Framework | Kestrel with ASP.NET Core in-process hosting, or IIS on .NET 5+ |
| IIS on Windows Server 2022+ | IIS with HTTP/2 + TLS and ASP.NET Core in-process hosting |
| Windows Service (`ServiceHost`) | An `IHostedService` / `BackgroundService` run via `sc.exe` or a service wrapper |
| Self-hosted console | `WebApplication.Run()` on Kestrel |
| COM+ / WAS activation | Not applicable; use container orchestration or a Windows Service instead |

### 1.4 IIS Constraints

End-to-end HTTP/2 gRPC support in IIS requires .NET 5+ and Windows Server
2022+ (or Windows 11). If the target OS does not meet this bar, host on
Kestrel behind a reverse proxy (IIS with Application Request Routing, nginx,
Envoy) that terminates or forwards HTTP/2 to Kestrel.

### 1.5 Named Pipes and Unix Domain Sockets

`NetNamedPipeBinding` can be replaced with ASP.NET Core's built-in named-pipe
or Unix-domain-socket transport for intra-machine gRPC:

```csharp
// Windows named pipe
builder.WebHost.ConfigureKestrel(options =>
    options.ListenNamedPipe("GrpcPipe", listenOptions =>
        listenOptions.Protocols = HttpProtocols.Http2));
```

---

## 2. Runtime and Framework Selection

The plugin recommends the current .NET LTS release unless the repository
already establishes a different target.

| .NET Version | Support Status (as of 2026-07-30) | gRPC Notes |
|-----------------|-----------------------------------------|-----------|
| .NET 8 (LTS) | Approaching end of support (Nov 10, 2026) | Full gRPC support; no longer recommended for new work given its short remaining support window |
| .NET 9 (STS) | Approaching end of support (Nov 10, 2026) | Full gRPC support; same end-of-support date as .NET 8 |
| .NET 10 (LTS) | Current LTS, released Nov 11, 2025; supported through Nov 14, 2028 | Full gRPC support; **recommended default target** for new migrations |
| .NET Framework 4.x | Out of scope for gRPC hosting | No Kestrel/HTTP.2 server; gRPC **client** only, via `WinHttpHandler` |

.NET Framework projects can host only a **gRPC client**, never a gRPC
server. Services still targeting .NET Framework must be rehosted on a
supported .NET version before they can serve gRPC traffic.

Always re-verify current support dates against
`https://dotnet.microsoft.com/platform/support/policy/dotnet-core` before
relying on this table for a specific migration, since support windows shift
with each release.

---

## 3. Coexistence Strategies

Running WCF and gRPC simultaneously lets consumers migrate in stages instead
of requiring a hard cutover.

### 3.1 Side-by-Side Services (same host, different endpoints)

Host WCF (`ServiceHost`) and gRPC (ASP.NET Core/Kestrel) on the same machine,
listening on different ports — for example WCF on port 5000 (HTTP/SOAP or
net.tcp) and gRPC on port 5001 (HTTPS/HTTP2). Both share the same business
logic layer (a shared library or DI service), and clients migrate
endpoint-by-endpoint.

**Pros:** minimal infrastructure change; rollback is trivial.
**Cons:** dual operational surface; duplicated instrumentation.

### 3.2 Reverse Proxy Coexistence

Place an Envoy or nginx reverse proxy in front of both services and route by
content type or host header — `Content-Type: application/grpc` to the gRPC
backend, `text/xml` / a `SOAPAction` header to the WCF backend. This
decouples consumer migration from service deployment.

### 3.3 SOAP Adapter for Legacy Consumers

If external SOAP consumers cannot be updated (third-party partners, legacy
systems), a **temporary SOAP adapter** can front the gRPC service:

1. The adapter receives a WSDL-compliant SOAP request.
2. It translates the SOAP envelope into a Protobuf message.
3. It calls the gRPC service.
4. It converts the Protobuf response back into a SOAP envelope.

This adapter is a **temporary bridge, not a migration destination**; it must
have an explicit retirement date recorded in the decision log. The long-term
goal remains migrating every consumer to gRPC directly.

Implementation options include custom ASP.NET Core middleware (SOAP parsing
plus a gRPC client call), or a third-party SOAP-to-gRPC shim such as
CoreWCF — neither is endorsed by this plugin as a permanent migration
target.

### 3.4 gRPC JSON Transcoding

For browser-based or REST consumers, ASP.NET Core's built-in gRPC JSON
transcoding can expose the same gRPC service as an HTTP/JSON API without a
separate REST implementation:

```protobuf
import "google/api/annotations.proto";

service OrderService {
  rpc GetOrder (GetOrderRequest) returns (Order) {
    option (google.api.http) = {
      get: "/v1/orders/{order_id}"
    };
  }
}
```

This is a **transparency feature** for consumers that cannot speak gRPC
natively, not a replacement for gRPC as the primary protocol — REST calls hit
the same underlying service implementation.

---

## 4. Rollout Phases

A safe migration follows these ordered phases. The orchestrator encodes them
as work-package dependencies.

### Phase 0: Baseline and Inventory (prerequisite)
- Capture WCF contract interfaces, WSDL, and sample messages.
- Record behavioral baselines: timing, error rates, payload sizes.
- Identify external consumers and who controls their upgrade schedule.
- Freeze WCF contracts (no new features) for the migration period.

### Phase 1: Shared Foundation (sequential; cannot be parallelized)
1. Define Protobuf package/version conventions and shared type definitions
   (`decimal.proto`, error-detail protos, etc.).
2. Stand up the ASP.NET Core hosting project with TLS, health checks, and
   observability (logging, metrics, tracing).
3. Implement authentication/authorization middleware.
4. Define the gRPC interceptor chain (error handling, logging, correlation).

### Phase 2: Pilot Service Slice
Choose the simplest, lowest-risk service (low traffic, few consumers, no
sessions/transactions) as the pilot:
1. Author the `.proto` file.
2. Implement the gRPC service class.
3. Deploy alongside the existing WCF service (side by side, §3.1).
4. Migrate one internal consumer to validate the pilot end to end.
5. Verify parity (§5).

### Phase 3: Parallel Service Migration (fleet-eligible)
Independent service slices with disjoint file ownership may be migrated in
parallel under fleet mode, once:
- Phase 1 is complete and stable.
- The pilot service is deployed and validated.
- No shared mutable state exists between the parallel services.
- Each fleet work package has explicit acceptance criteria and validation
  commands.

### Phase 4: Consumer Migration
Migrate consumers from WCF clients to gRPC clients:
- Internal consumers migrate together with the service.
- External consumers require a negotiated timeline and coexistence (§3.1–3.4)
  during the transition.

### Phase 5: WCF Retirement
Retire WCF endpoints only when:
- Every consumer is confirmed migrated to gRPC.
- Parity validation (§5) passes.
- Monitoring shows zero traffic on WCF endpoints for an agreed quiesce
  period.
- The decision log records explicit retirement approval.

---

## 5. Parity Validation Criteria

`validate-grpc-parity` asserts parity before WCF retirement is permitted.

### 5.1 Contract Parity
- Every `[OperationContract]` has a corresponding `rpc` method.
- Every `[DataContract]` field has a corresponding Protobuf field of a
  compatible type, with any semantic differences documented.
- Field numbers are stable; no regressions since the previous spec version.

### 5.2 Behavioral Parity
- Success paths: the same request produces an equivalent response (allowing
  for known semantic differences such as timestamp UTC normalization).
- Error paths: input that previously caused a WCF `FaultException` now
  produces an `RpcException` with the mapped `StatusCode`.
- Authorization: a principal authorized/denied under WCF is
  authorized/denied identically under gRPC.
- Deadlines: requests that exceed the configured timeout fail with
  `DEADLINE_EXCEEDED`.

### 5.3 Performance Parity
- Response latency (P50/P95/P99) is within agreed bounds relative to the WCF
  baseline.
- Payload sizes are equal to or smaller than before; Protobuf is typically
  smaller than SOAP/XML, so a regression suggests a mapping error.

### 5.4 Operational Readiness
- The health-check endpoint answers readiness and liveness probes correctly.
- Structured logs include correlation IDs and service names.
- Distributed traces (OpenTelemetry) propagate across service boundaries.
- Alerts and dashboards are configured for the gRPC service.

### 5.5 Cancellation and Concurrency
- Client-side cancellation is honored (the server stops work once
  `CancellationToken` is raised).
- Concurrent calls do not cause data corruption or deadlocks.
- Scoped DI services do not leak state between requests.

### 5.6 Blocking vs. Non-Blocking Findings

Each finding must be classified:
- **Blocking:** prevents WCF retirement (for example, data corruption, an
  authorization bypass, a missing operation, or a crash).
- **Non-blocking:** must be resolved before a subsequent release but does not
  block immediate retirement (for example, a missing non-critical log field,
  or a performance metric that is within threshold but trending worse).

---

## 6. Rollback Plan

Each migration phase must include a rollback procedure:
- Keep the WCF service active and routable until the Phase 5 exit criteria
  are met.
- Use feature flags or load-balancer/DNS routing weights to shift traffic
  back to WCF if a regression is detected in gRPC.
- Version `.proto` files; reverting the gRPC service to a prior version must
  not require consumer recompilation as long as only backward-compatible
  field additions were made since that version.
- Any database migrations must be additive and reversible for the duration
  of the coexistence period.
