# Source Index

All claims in the `map-wcf-to-grpc` reference files are derived from the
sources listed here. Official Microsoft and Google/gRPC sources are treated
as normative. Any source not published by Microsoft, Google, or the gRPC
project is explicitly labelled **[third-party]** below and is used only for
supplementary context or illustrative patterns — never as the basis for a
mandatory mapping rule.

**Access date for every source in this index: 2026-07-30.**

---

## Primary Sources

### S1 — Microsoft .NET Architecture: gRPC for WCF Developers (e-book)
- **Format:** PDF, local copy
- **Local path:** `assets/gRPC-for-WCF-Developers.pdf`
- **Online edition:** <https://learn.microsoft.com/en-us/dotnet/architecture/grpc-for-wcf-developers/>
- **Publisher:** Microsoft Corporation (.NET Architecture guide series)
- **Authors:** Mark Rendle, Miranda Steiner
- **Notes:** The canonical Microsoft reference for WCF-to-gRPC migration,
  covering service contracts, data contracts, bindings, security, and
  streaming. Used as the primary source for normative migration guidance in
  this skill. Content is summarized in original language throughout these
  references; the source text is not reproduced.

### S2 — ASP.NET Core gRPC documentation area (overview)
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/>
- **Publisher:** Microsoft Corporation
- **Notes:** Landing page for gRPC on ASP.NET Core: Protobuf tooling,
  hosting, and client creation. Used for general hosting and tooling claims.

### S3 — gRPC services with ASP.NET Core
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/aspnetcore>
- **Publisher:** Microsoft Corporation
- **Notes:** Kestrel configuration, IIS/HTTP.sys hosting, named-pipe and
  non-ASP.NET-Core project hosting. Used for hosting-topology claims.

### S4 — Create gRPC services and methods
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/services>
- **Publisher:** Microsoft Corporation
- **Notes:** Unary, server-streaming, client-streaming, and bidirectional
  method signatures and lifecycles. Used for streaming mapping claims.

### S5 — Authentication and authorization in gRPC for ASP.NET Core
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/authn-and-authz>
- **Publisher:** Microsoft Corporation
- **Notes:** Bearer-token (JWT) authentication, client certificates, and
  `[Authorize]` integration. Used for all authentication mapping claims.

### S6 — Security considerations in gRPC for ASP.NET Core
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/security>
- **Publisher:** Microsoft Corporation
- **Notes:** TLS configuration, exception-detail exposure policy, message
  size limits, client-certificate validation. Used for security and error
  handling claims.

### S7 — Configure gRPC-related options on .NET
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/configuration>
- **Publisher:** Microsoft Corporation
- **Notes:** `GrpcServiceOptions` (`MaxReceiveMessageSize`,
  `MaxSendMessageSize`, `EnableDetailedErrors`, interceptors) and
  `GrpcChannelOptions`. Used for binding/quota mapping claims.

### S8 — Configure deadline and cancellation in gRPC apps on .NET
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/deadlines-cancellation>
- **Publisher:** Microsoft Corporation
- **Notes:** `CallOptions.Deadline`, `ServerCallContext.CancellationToken`,
  and `EnableCallContextPropagation`. Used for timeout/deadline mapping
  claims.

### S9 — Retries for resilient gRPC apps on .NET
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/retries>
- **Publisher:** Microsoft Corporation
- **Notes:** `RetryPolicy`, `HedgingPolicy`, and streaming-retry
  constraints. Used for retry and fault-tolerance claims.

### S10 — Call gRPC services with a .NET client / gRPC interceptors
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/interceptors>
- **Publisher:** Microsoft Corporation
- **Notes:** Server and client interceptors as the replacement for WCF
  message inspectors and `IErrorHandler`. Used for behavior/extensibility
  mapping claims.

### S11 — Compare gRPC services with HTTP APIs
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/comparison>
- **Publisher:** Microsoft Corporation
- **Notes:** gRPC-vs-REST feature comparison and browser limitations. Used
  for coexistence and browser-support claims.

### S12 — gRPC-Web in ASP.NET Core gRPC apps
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/grpcweb>
- **Publisher:** Microsoft Corporation
- **Notes:** gRPC-Web protocol, CORS, and HTTP/1.1 + HTTP/2 configuration.
  Used for browser-consumer coexistence claims.

### S13 — Migrate gRPC services and clients from C-core to grpc-dotnet
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/migration>
- **Publisher:** Microsoft Corporation
- **Notes:** Service lifetime (scoped vs. singleton), configuration
  migration, logging, and HTTPS considerations. Used for instance-mode and
  service-lifetime mapping claims.

### S14 — Protocol Buffers Language Guide (proto3)
- **URL:** <https://protobuf.dev/programming-guides/proto3/>
- **Publisher:** Google LLC
- **Notes:** Canonical proto3 reference: scalar types, field cardinality,
  `optional`, `repeated`, `map`, `oneof`, `reserved`, and enums. Used for all
  Protobuf type-mapping claims.

### S15 — Protocol Buffers well-known types reference
- **URL:** <https://protobuf.dev/reference/protobuf/google.protobuf/>
- **Publisher:** Google LLC
- **Notes:** `Timestamp`, `Duration`, `Any`, and the (now legacy) wrapper
  types. Used for date/time, `decimal`, and polymorphism mapping claims.

### S16 — gRPC status codes
- **URL:** <https://grpc.io/docs/guides/status-codes/>
- **Publisher:** gRPC Authors (Cloud Native Computing Foundation / Google LLC)
- **Notes:** Normative definitions for all 17 gRPC status codes with
  use-case guidance. Used for the WCF-fault-to-gRPC-status-code mapping
  table.

### S17 — gRPC over HTTP/2 protocol specification
- **URL:** <https://github.com/grpc/grpc/blob/master/doc/PROTOCOL-HTTP2.md>
- **Publisher:** gRPC Authors (Google LLC)
- **Notes:** Wire-level protocol definition. Referenced for claims about
  metadata (HTTP/2 headers), trailers, and status propagation.

---

## Supplementary Sources

### S18 — gRPC JSON transcoding in ASP.NET Core gRPC apps
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/grpc/json-transcoding>
- **Publisher:** Microsoft Corporation
- **Notes:** Exposing a gRPC service as an HTTP/JSON API for browser/REST
  consumers. Referenced for coexistence §3.4 in `hosting-and-rollout.md`.

### S19 — Configure certificate authentication in ASP.NET Core
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/security/authentication/certauth>
- **Publisher:** Microsoft Corporation
- **Notes:** `Microsoft.AspNetCore.Authentication.Certificate` package and
  client-certificate validation configuration. Referenced for mTLS claims in
  `security-mapping.md`.

### S20 — Configure endpoints for the ASP.NET Core Kestrel web server
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel/endpoints>
- **Publisher:** Microsoft Corporation
- **Notes:** `UseHttps`, named pipes, Unix domain sockets, and ALPN.
  Referenced for hosting and TLS configuration claims.

### S21 — Dependency injection in ASP.NET Core — service lifetimes
- **URL:** <https://learn.microsoft.com/en-us/aspnet/core/fundamentals/dependency-injection>
- **Publisher:** Microsoft Corporation
- **Notes:** Scoped, singleton, and transient service lifetimes. Referenced
  for instance-mode mapping in `feature-mapping.md` and
  `error-and-streaming-mapping.md`.

### S22 — .NET and .NET Core official support policy [advisory]
- **URL:** <https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core>
- **Publisher:** Microsoft Corporation
- **Notes:** Authoritative LTS/STS release and end-of-support dates. Used to
  confirm the current-LTS recommendation in `hosting-and-rollout.md` §2 at
  access time: .NET 8 and .NET 9 both reach end of support on 2026-11-10;
  .NET 10 (released 2025-11-11) is the current LTS, supported through
  2028-11-14. Re-check this page before relying on the recommendation, since
  support windows change with every release.

---

## Version and Currency Notes

- Microsoft Learn gRPC URLs above omit the `view=` moniker query parameter so
  they always resolve to the current default runtime version; confirm the
  active moniker matches the migration's target runtime before citing a page
  as authoritative for a specific .NET version.
- The `gRPC-for-WCF-Developers.pdf` e-book (S1) predates .NET 8 and does not
  cover .NET 8/9/10-specific APIs. Where the book's guidance conflicts with
  more recent Microsoft Learn documentation, the Learn documentation takes
  precedence.
- Protobuf Editions syntax (the successor to `syntax = "proto3";`) is
  documented at <https://protobuf.dev/programming-guides/editions>. This
  plugin targets proto3 as the widely supported default; adopting Protobuf
  Editions instead is an explicit decision to be recorded in the decision
  log, not an automatic upgrade.
