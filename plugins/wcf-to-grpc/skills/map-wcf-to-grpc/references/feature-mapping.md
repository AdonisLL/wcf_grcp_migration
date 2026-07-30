# WCF-to-gRPC Feature Mapping Reference

> **Scope:** Guidance for mapping WCF service-model constructs (contracts,
> bindings, behaviors, instance/concurrency modes, extensibility points, and
> observability) to gRPC on ASP.NET Core. Each entry states a risk level.
> **LOW** = mechanical change, **MEDIUM** = semantic difference requiring
> review, **HIGH** = no direct equivalent; an architectural redesign and a
> recorded decision are required. See `sources.md` for full citations.

---

## 1. Service and Operation Contracts

### 1.1 `[ServiceContract]` → Protobuf `service`

A `[ServiceContract]` interface maps to a Protobuf `service` block. The
mapping is mechanical once the service boundary is confirmed.

```protobuf
// WCF: [ServiceContract] IOrderService
service OrderService {
  // rpc methods derived from [OperationContract] members
}
```

**Risk: LOW.** Considerations:
- The Protobuf `package` takes the role of the WCF XML namespace; use a
  stable, versioned package path (for example `acme.orders.v1`).
- WCF allows service-contract interface inheritance; Protobuf `service`
  blocks do not support inheritance. Flatten the hierarchy or duplicate
  methods across services.

### 1.2 `[OperationContract]` → `rpc` method

| WCF shape | gRPC shape | Risk |
|-----------|-----------|------|
| Request/response (sync or `AsyncPattern`) | Unary `rpc Foo(Req) returns (Resp)` | LOW |
| `IsOneWay = true` | Unary with empty response, or client streaming (§4.1) | MEDIUM |
| Duplex callback contract | Bidirectional streaming (§4.3) | HIGH |

**Required changes:**
- Every `rpc` method has exactly one request message and one response
  message; multi-parameter WCF methods need a wrapper request message.
- `void` returns become an empty response message or `google.protobuf.Empty`.
- `OperationContext.Current` has no gRPC equivalent; correlation/context data
  travels as gRPC metadata via `ServerCallContext.RequestHeaders`.

### 1.3 `[MessageContract]` → Protobuf `message`

`[MessageContract]` gives control over SOAP header/body structure. Message
body parts map directly to Protobuf message fields. SOAP header fields used
for authentication or correlation should move to gRPC metadata. SOAP part
ordering and XML namespace constraints are dropped; Protobuf identifies
fields by number, not order.

**Risk: MEDIUM.** Any consumer that depends on the literal SOAP envelope
shape breaks; this is a breaking change for remaining SOAP consumers.

### 1.4 `[DataContract]` / `[DataMember]` → Protobuf `message` / fields

See `protobuf-type-mapping.md` for field-level type mapping.

**Risk: MEDIUM.** Nullability and zero-value semantics differ between
`DataContract` and proto3; see `protobuf-type-mapping.md` §2.

### 1.5 `[FaultContract]` → gRPC status + rich error details

See `error-and-streaming-mapping.md` §1.

---

## 2. Bindings

WCF bindings bundle transport, encoding, and security. gRPC on ASP.NET Core
always uses HTTP/2 with Protobuf encoding and TLS; there is no one-to-one
binding concept, so each binding property is mapped to an explicit Kestrel,
channel, or ASP.NET Core configuration setting.

| WCF Binding | gRPC Equivalent | Risk |
|-------------|-----------------|------|
| `BasicHttpBinding` | gRPC unary over HTTPS | LOW–MEDIUM (SOAP interop is lost) |
| `WSHttpBinding` | gRPC over HTTPS with a JWT or certificate credential (`security-mapping.md`) | MEDIUM–HIGH |
| `NetTcpBinding` | gRPC over HTTPS on Kestrel | LOW |
| `NetNamedPipeBinding` | gRPC over a named pipe or Unix domain socket | LOW–MEDIUM |
| `NetMsmqBinding` | **UNSUPPORTED** — no gRPC transport for durable queuing | HIGH |
| `WSDualHttpBinding` (duplex) | Bidirectional streaming (redesign required) | HIGH |
| `WebHttpBinding` (REST) | gRPC JSON transcoding, or a separate concern | MEDIUM |

**`NetMsmqBinding` / MSMQ:** gRPC has no built-in durable queue transport.
This is a **HIGH**-risk unsupported feature: affected operations require a
redesign around an external message broker (an explicit decision from the
user) exposed via a gRPC client-streaming method or a dedicated adapter
service. Do not silently substitute a REST or non-gRPC queue consumer.

**`NetNamedPipeBinding`:** ASP.NET Core gRPC supports intra-machine IPC over
Unix domain sockets or Windows named pipes. This is a supported, low-risk
alternative.

### 2.1 Timeouts and Quotas

| WCF Setting | gRPC Equivalent |
|-------------|------------------|
| `SendTimeout` | Client-side `CallOptions.Deadline` |
| `ReceiveTimeout` / `OpenTimeout` | `ServerCallContext.CancellationToken` / Kestrel keep-alive settings |
| `MaxReceivedMessageSize` | `GrpcServiceOptions.MaxReceiveMessageSize` / `MaxSendMessageSize` |
| `MaxBufferPoolSize` | No direct equivalent; managed by Kestrel/.NET memory pooling |
| `TransferMode` (streamed) | gRPC streaming methods (§4) |

Timeout values must be converted from a relative `TimeSpan` to an absolute
deadline (`DateTime.UtcNow + offset`) for `CallOptions.Deadline`. gRPC has
**no default deadline**; every production call must set one explicitly.

---

## 3. Service Behaviors and Instance Modes

### 3.1 `ServiceBehaviorAttribute`

| WCF Property | gRPC / ASP.NET Core Equivalent | Risk |
|---------------|--------------------------------|------|
| `InstanceContextMode.PerCall` | Default ASP.NET Core scoped service lifetime | LOW |
| `InstanceContextMode.PerSession` | **UNSUPPORTED** — gRPC has no session concept | HIGH |
| `InstanceContextMode.Singleton` | Register the service with `AddSingleton` | LOW |
| `ConcurrencyMode.Single` | Not applicable; concurrency is governed by DI lifetime | LOW |
| `ConcurrencyMode.Multiple` | Default ASP.NET Core behavior | LOW |
| `ConcurrencyMode.Reentrant` | **UNSUPPORTED** — replace with async/await | HIGH |
| `MaxItemsInObjectGraph` | No equivalent; Protobuf has no object-graph cycle detection | MEDIUM |

**`PerSession` / session state:** a HIGH-risk unsupported feature. gRPC
services are stateless by design. Per-session state must be externalized to
an explicit store (database or distributed cache) keyed by a client-supplied
correlation identifier. This is an architectural decision that must be
recorded and approved before specification authoring proceeds.

### 3.2 Throttling

| WCF Setting | gRPC / ASP.NET Core Equivalent |
|-------------|--------------------------------|
| `MaxConcurrentCalls` | ASP.NET Core rate-limiting middleware / concurrency limits |
| `MaxConcurrentSessions` | Not applicable (no sessions) |
| `MaxConcurrentInstances` | DI lifetime management |

### 3.3 Message Inspectors and Behaviors

`IDispatchMessageInspector` and `IClientMessageInspector` intercept SOAP
messages before/after dispatch. The gRPC equivalent is a **gRPC
interceptor** (`Interceptor` base class, server- or client-side) or, for
HTTP-level concerns, ASP.NET Core middleware.

- Use interceptors for gRPC-specific concerns (auth, logging, correlation);
  they see `ServerCallContext` / `ClientInterceptorContext` and can inspect
  or modify metadata, or short-circuit the call with an `RpcException`.
- Use middleware for HTTP/2-level concerns (rate limiting, health probes).

**Risk: MEDIUM.** Inspector code that parses SOAP headers or XML elements
must be rewritten against Protobuf messages and gRPC metadata.

### 3.4 `IErrorHandler`

See `error-and-streaming-mapping.md` §1.4 for the interceptor-based
replacement.

---

## 4. Communication Patterns

### 4.1 One-Way Operations (`IsOneWay = true`)

WCF one-way operations return to the caller immediately without waiting for
completion. gRPC has no built-in fire-and-forget RPC.

**Migration options (choose with the user):**
1. **Unary with an empty response** — client awaits the server but discards
   the result; simplest, adds one round trip.
2. **Client streaming** — client sends one or more messages, server sends a
   single final response; suited to batching.
3. **Bidirectional streaming** — full duplex; more complex, used only when
   asynchronous acknowledgement is required.

**Risk: MEDIUM.** The caller's threading model changes, and errors that WCF
silently dropped on the server side now surface as a gRPC status; error
handling must be explicitly designed.

### 4.2 Request-Response (Unary)

Maps directly to a unary `rpc`. This is the lowest-risk migration path.

### 4.3 Duplex Callbacks (`CallbackContract`)

WCF duplex lets the server call back into the client through a
`CallbackContract`. gRPC has no equivalent callback mechanism.

**Required redesign (HIGH risk):** replace with **bidirectional streaming**:
the client opens a long-lived stream, the server writes messages onto it
whenever it has data, and the client reads them as callbacks.

Lifecycle differences that must be documented in the migration spec:
- The client must keep the stream open explicitly; WCF managed this via a
  session.
- The stream lives only as long as the underlying RPC call.
- The server cannot push data to the client outside an active call.
- Reconnection and missed-message handling become application
  responsibilities.

This is a **HIGH**-risk unsupported feature requiring an explicit decision
before the spec can be authored.

---

## 5. Extensibility Points

| WCF Extension | gRPC Equivalent | Risk |
|----------------|------------------|------|
| `IOperationInvoker` | Override the generated `*Base` method | LOW |
| `IParameterInspector` | Server interceptor | MEDIUM |
| `IDispatchMessageInspector` | Server interceptor | MEDIUM |
| `IClientMessageInspector` | Client interceptor | MEDIUM |
| `IServiceBehavior` | DI + interceptors + middleware | MEDIUM |
| `IEndpointBehavior` | Channel configuration + interceptors | MEDIUM |
| `IContractBehavior` | Protobuf service options + interceptors | MEDIUM |
| `IChannelInitializer` | `GrpcChannelOptions` configuration | LOW |
| Custom `BindingElement` | Custom `HttpMessageHandler` pipeline | MEDIUM |

---

## 6. Observability

| WCF Feature | gRPC Equivalent |
|--------------|------------------|
| `System.Diagnostics` tracing | ASP.NET Core `ILogger` + OpenTelemetry |
| WCF performance counters | .NET metrics + OpenTelemetry metrics |
| `DiagnosticSource` | `ActivitySource` / OpenTelemetry tracing |
| Message logging | gRPC/ASP.NET Core logging (`EnableDetailedErrors` in development only) |
| WS-Management | **UNSUPPORTED** — use cloud-native orchestration/observability instead |

---

## 7. Generated Clients

WCF clients are generated from WSDL (Add Service Reference / `svcutil`). gRPC
clients are generated from `.proto` files by the `Grpc.Tools` package via
`<Protobuf Include="..." />` in the project file.

External SOAP consumers of a WCF service remain a major compatibility risk.
Consumers that cannot be updated require a temporary coexistence adapter; see
`hosting-and-rollout.md` §3.
