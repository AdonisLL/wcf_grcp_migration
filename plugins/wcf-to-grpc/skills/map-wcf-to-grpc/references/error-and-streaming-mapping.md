# Error, Streaming, Session, and Transaction Mapping Reference

> **Scope:** Mapping WCF fault contracts and error handling, communication
> patterns (streaming, sessions, callbacks, one-way operations), instance
> management, and transactional behavior to gRPC equivalents. Constructs with
> no direct gRPC equivalent are documented as redesign risks. The target is
> always gRPC on ASP.NET Core. Risk levels follow `feature-mapping.md`. See
> `sources.md` for citations.

---

## 1. Fault Contracts and Error Handling

### 1.1 WCF Fault Model vs. gRPC Error Model

WCF uses typed SOAP faults: an operation declares
`[FaultContract(typeof(OrderFault))]`, the server throws
`FaultException<OrderFault>`, and the client catches
`FaultException<OrderFault>` to read the detail object.

gRPC uses a **status code + optional rich error detail** model: the server
throws `RpcException(new Status(StatusCode.X, "message"))`, and the client
catches `RpcException` and reads `ex.StatusCode` / `ex.Status`. Rich,
structured error details use `google.rpc.Status` with `Any`-packed
extensions.

### 1.2 gRPC Status Code Reference

| Code | Number | Typical WCF Scenario |
|------|--------|------------------------|
| `OK` | 0 | Successful call |
| `CANCELLED` | 1 | Client disposed the call / cancelled its token |
| `UNKNOWN` | 2 | Unhandled server exception |
| `INVALID_ARGUMENT` | 3 | Invalid request data (replaces validation faults) |
| `DEADLINE_EXCEEDED` | 4 | `SendTimeout` / `ReceiveTimeout` exceeded |
| `NOT_FOUND` | 5 | Requested entity does not exist |
| `ALREADY_EXISTS` | 6 | Duplicate creation attempt |
| `PERMISSION_DENIED` | 7 | Authorization failure (authenticated, not authorized) |
| `RESOURCE_EXHAUSTED` | 8 | Throttling / quota exceeded |
| `FAILED_PRECONDITION` | 9 | System not in a valid state; an immediate retry will not help |
| `ABORTED` | 10 | Concurrency conflict; caller should retry at a higher level |
| `OUT_OF_RANGE` | 11 | Value outside its valid range |
| `UNIMPLEMENTED` | 12 | Method not implemented |
| `INTERNAL` | 13 | Server invariant broken; serious error |
| `UNAVAILABLE` | 14 | Transient failure; safe to retry with backoff |
| `DATA_LOSS` | 15 | Unrecoverable data corruption |
| `UNAUTHENTICATED` | 16 | Missing or invalid credentials |

### 1.3 Mapping Typed Faults to Rich Error Details

WCF `FaultException<T>` carries a strongly typed detail object. The gRPC
equivalent embeds a `google.rpc.Status` message, with `Any`-packed detail
fields, in the call's trailing metadata.

**Pattern:**
1. Define the error-detail message in a shared `.proto` file.
2. Build a `google.rpc.Status` with `code`, `message`, and `details`.
3. Serialize it and attach it as the `grpc-status-details-bin` trailer.

```protobuf
// errors/order_errors.proto
syntax = "proto3";
import "google/rpc/error_details.proto";

message OrderNotFoundDetail {
  string order_id = 1;
  string reason = 2;
}
```

```csharp
// Server
var detail = new OrderNotFoundDetail { OrderId = "123", Reason = "Archived" };
var status = new Google.Rpc.Status
{
    Code = (int)StatusCode.NotFound,
    Message = "Order not found",
    Details = { Google.Protobuf.WellKnownTypes.Any.Pack(detail) }
};
throw status.ToRpcException();
```

Helper packages (such as `Grpc.StatusProto`) provide pack/unpack helpers for
`google.rpc.Status` details.

**Risk: MEDIUM.** Requires a shared proto package for error-detail types;
both client and server reference the same generated types, and existing WCF
client code that catches `FaultException<T>` must be rewritten to catch
`RpcException` and unpack the detail.

### 1.4 `IErrorHandler` → Server Interceptor

WCF `IErrorHandler.HandleError` / `ProvideFault` centralizes exception
handling. The gRPC equivalent is a server interceptor wrapping the unary (and
streaming) handlers in a try/catch:

```csharp
public class ErrorInterceptor : Interceptor
{
    public override async Task<TResponse> UnaryServerHandler<TRequest, TResponse>(
        TRequest request,
        ServerCallContext context,
        UnaryServerMethod<TRequest, TResponse> continuation)
    {
        try { return await continuation(request, context); }
        catch (DomainException ex)
        {
            throw new RpcException(
                new Status(StatusCode.FailedPrecondition, ex.Message));
        }
        catch (Exception)
        {
            throw new RpcException(
                new Status(StatusCode.Internal, "An internal error occurred."));
        }
    }
}
```

Register globally: `services.AddGrpc(o => o.Interceptors.Add<ErrorInterceptor>())`.

**Risk: LOW** once the interceptor is written.

### 1.5 Exception Message Exposure

By default, gRPC returns a generic error message to the client; exception
details are logged server-side only. `EnableDetailedErrors = true` on
`GrpcServiceOptions` surfaces full details for local development and
**must never be enabled in production**, since it can leak stack traces and
sensitive data.

---

## 2. Streaming

### 2.1 WCF Streaming vs. gRPC Streaming

WCF supports message streaming via `TransferMode.Streamed` variants, avoiding
full in-memory buffering of large payloads. gRPC provides four first-class
communication shapes.

| Pattern | WCF Mechanism | gRPC Method Shape |
|---------|-----------------|--------------------|
| No streaming | Default request/response | `rpc Foo(Req) returns (Resp)` |
| Server streaming | Streamed response / push notification | `rpc Foo(Req) returns (stream Resp)` |
| Client streaming | Streamed request | `rpc Foo(stream Req) returns (Resp)` |
| Bidirectional streaming | Duplex / `WSDualHttpBinding` | `rpc Foo(stream Req) returns (stream Resp)` |

### 2.2 Server Streaming

```csharp
public override async Task ListOrders(
    ListOrdersRequest request,
    IServerStreamWriter<Order> responseStream,
    ServerCallContext context)
{
    await foreach (var order in _repo.GetOrdersAsync(context.CancellationToken))
    {
        await responseStream.WriteAsync(order);
    }
}
```

Always observe `context.CancellationToken` to exit cleanly when the client
cancels; the stream closes when the method returns.

### 2.3 Client Streaming

```csharp
public override async Task<UploadResult> UploadChunks(
    IAsyncStreamReader<Chunk> requestStream,
    ServerCallContext context)
{
    await foreach (var chunk in requestStream.ReadAllAsync())
    {
        await _store.WriteAsync(chunk.Data.ToByteArray(), context.CancellationToken);
    }
    return new UploadResult { BytesWritten = _store.TotalBytes };
}
```

### 2.4 Bidirectional Streaming

Both sides can send messages at any time while the call is open. This is the
primary replacement for WCF duplex callbacks (§3) and for event-driven
patterns. Lifecycle constraints that must be documented in the migration
spec:
- The stream's lifetime is bounded by the RPC call; there is no persistent,
  server-initiated connection outside an active call.
- If the client disconnects, `CancellationToken` is raised on the server.
- The server cannot initiate a new call to the client — it can only respond
  within a stream the client already opened.

### 2.5 Retry Behavior with Streaming

Automatic gRPC retry policies (`RetryPolicy` on `MethodConfig`) have limited
applicability to streaming calls: bidirectional/server-streaming calls will
not retry once the first response message has been received, and
client-streaming calls will not retry once outgoing messages exceed the
retry buffer. Long-lived streams need application-level reconnection logic.

---

## 3. Duplex Callbacks — UNSUPPORTED (HIGH risk)

WCF duplex contracts let the server invoke operations on the client through a
`CallbackContract`. There is **no direct gRPC equivalent**.

**Required redesign:** bidirectional streaming (§2.4) is the canonical
replacement, but the semantic differences are significant and must be
explicitly specified:

| WCF Duplex | gRPC Bidirectional Streaming |
|--------------|---------------------------------|
| Server can call the client at any time after connection | Server can send only within an RPC stream the client initiated |
| `CallbackContract` is a typed interface | Server writes typed stream messages; client reads via `ResponseStream.ReadAllAsync()` |
| WCF manages the session | The application manages stream lifetime and reconnection |
| Callback failures surface via `IErrorHandler` | `CancellationToken` is raised; the client must detect and reconnect |
| Multiple in-flight callbacks possible | Messages are ordered on the stream; full-duplex read/write requires careful task management |

**Decisions required from the user:**
- What happens when the client disconnects (missed callbacks)?
- Is at-least-once delivery required (requires an application-level
  acknowledgement protocol over the stream)?
- Should the stream reconnect automatically (requires client-side retry
  logic)?

This is a **HIGH**-risk unsupported feature that blocks specification
authoring until resolved.

---

## 4. Sessions and Reliable Messaging — UNSUPPORTED (HIGH risk)

### 4.1 WCF Session State (`InstanceContextMode.PerSession`)

WCF sessions let a client and server instance share state across multiple
calls. gRPC services are stateless — each RPC call is independent, and gRPC
and HTTP/2 have no session concept.

**Required redesign:**
1. The client generates a session or correlation identifier and includes it
   in request metadata or message fields.
2. The server looks up state from a shared store (SQL, Redis, Cosmos DB, etc.)
   keyed by that identifier.
3. State lifetime and eviction must be managed explicitly by the
   application.

This is a **HIGH**-risk redesign; record it as an open architectural
decision.

### 4.2 WS-ReliableMessaging

`NetTcpBinding` with a reliable session enabled uses WS-ReliableMessaging to
guarantee ordered, exactly-once delivery. gRPC over HTTP/2 guarantees ordered
delivery within a single stream, but does not guarantee delivery across
reconnects, and has no native exactly-once semantics.

**Required redesign:** where ordered or exactly-once delivery across
connections is required, implement an idempotency key per message, a durable
outbox on the sender side, and an application-level acknowledgement protocol
over the gRPC stream.

This is a **HIGH**-risk unsupported feature.

---

## 5. Distributed Transactions — UNSUPPORTED (HIGH risk)

WCF supports `System.Transactions` (`TransactionScopeRequired = true` on
`OperationBehaviorAttribute`), flowing an ambient distributed transaction
(MSDTC / WS-AtomicTransaction) across service boundaries.

**gRPC has no support for distributed transactions.** HTTP/2 carries no
transaction context, and WS-AtomicTransaction depends on WS-* protocols not
available in gRPC.

**Required redesign** (decision required from the user); common patterns:
- **Saga pattern:** decompose the distributed transaction into a sequence of
  local transactions with compensating rollback actions.
- **Outbox pattern:** write events to a local database table atomically, then
  publish them to downstream services asynchronously.
- **Application-level two-phase commit:** a coordinator service implementing
  a prepare → commit/rollback protocol over gRPC calls.

The right pattern depends on the consistency requirements, failure modes, and
operational complexity the user is willing to accept.

This is a **HIGH**-risk blocking issue — the migration spec cannot describe
these operations until a pattern is chosen and approved.

---

## 6. One-Way Operations (`IsOneWay = true`)

See `feature-mapping.md` §4.1 for the full set of options. Summary risk
table:

| Replacement Strategy | Risk | Notes |
|--------------------------|------|-------|
| Unary with an empty `google.protobuf.Empty` response | MEDIUM | Client awaits acknowledgement; simplest code |
| Client streaming (batch, acknowledge once) | MEDIUM | Suitable for batching |
| Bidirectional streaming (no-op response channel) | HIGH | Complex; avoid unless genuinely needed |

The key semantic difference: WCF one-way calls may silently drop server-side
errors, whereas gRPC returns a status even for the simplest replacement.
Error handling must be explicitly designed.

---

## 7. Concurrency and Instance Management

| WCF `ConcurrencyMode` / `InstanceContextMode` | gRPC / ASP.NET Core Equivalent | Risk |
|---------------------------------------------------|--------------------------------|------|
| `PerCall` + `Multiple` | Default scoped DI lifetime + async methods | LOW |
| `Singleton` + `Single` | `AddSingleton` + `SemaphoreSlim` / `lock` | LOW |
| `PerSession` + any concurrency mode | **UNSUPPORTED** — see §4.1 | HIGH |
| `Reentrant` | **UNSUPPORTED** — replace with async/await | HIGH |

gRPC services have a scoped lifetime by default in ASP.NET Core (one
instance per request), equivalent to WCF's `PerCall`. Code that relies on
`OperationContext.Current` for instance-level state does not compile against
gRPC and must be refactored.

---

## 8. Deadlines vs. WCF Timeouts

| WCF Timeout | gRPC Equivalent |
|----------------|--------------------|
| `SendTimeout` on the binding | `CallOptions.Deadline` on each client call |
| `ReceiveTimeout` on the binding | `ServerCallContext.CancellationToken` / `Deadline` on the server |
| `OpenTimeout` / `CloseTimeout` | Channel connection options managed by `GrpcChannel` |

gRPC deadlines propagate through call chains. Use
`EnableCallContextPropagation()` on the client factory to automatically
forward the incoming call's deadline to downstream calls; without
propagation, a request can exceed its overall deadline because downstream
calls carry no time limit. gRPC has **no default deadline** — every
production call must set one explicitly.

---

## 9. Health Checks

WCF exposes metadata endpoints (MEX, WSDL). gRPC uses the standardized
`grpc.health.v1` health-check protocol:

```protobuf
// from grpc.health.v1 (standard; via the Grpc.HealthCheck package)
service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
  rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}
```

Add the `Grpc.AspNetCore.HealthChecks` package and call
`services.AddGrpcHealthChecks()` in `Program.cs`. Orchestrators (Kubernetes,
Azure Load Balancer) poll the health endpoint before routing traffic.

---

## 10. Summary: Unsupported Features Requiring Redesign

| WCF Feature | Risk | Prerequisite Decision |
|---------------|------|---------------------------|
| `SecurityMode.Message` (WS-Security) | HIGH | Replacement encryption/signing strategy |
| Windows / Kerberos authentication | HIGH | Identity-provider replacement |
| WS-AtomicTransaction / MSDTC | HIGH | Saga / outbox / application-level 2PC |
| WS-ReliableMessaging | HIGH | Idempotency + application-level acknowledgement |
| `InstanceContextMode.PerSession` | HIGH | External session-store design |
| Duplex `CallbackContract` | HIGH | Bidirectional-streaming lifecycle design |
| `NetMsmqBinding` / MSMQ transport | HIGH | External queue-broker decision |
| WS-Federation / CardSpace | HIGH | OIDC replacement |
| `ConcurrencyMode.Reentrant` | HIGH | Async refactoring design |
| MTOM binary attachments | HIGH | `bytes` field or external blob store |
| Raw `XmlElement` / `XmlDocument` payload | HIGH | Structured Protobuf replacement, or a string wrapper |
| WS-Management / WS-Eventing | HIGH | Cloud-native operations / event-bus decision |
