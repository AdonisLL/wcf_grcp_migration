# Security and Authorization Mapping Reference

> **Scope:** Mapping from WCF security modes and credential types to gRPC /
> ASP.NET Core equivalents. Constructs with no direct gRPC equivalent are
> marked **UNSUPPORTED** and flagged as redesign risks. The target is always
> gRPC on ASP.NET Core; this reference does not substitute REST or CoreWCF as
> a workaround. Risk levels follow `feature-mapping.md`. See `sources.md`.

---

## 1. WCF Security Mode Mapping

WCF's `SecurityMode` enum has four values; their gRPC equivalents vary
significantly in complexity.

| WCF `SecurityMode` | gRPC Equivalent | Risk |
|----------------------|------------------|------|
| `None` | Plaintext HTTP/2 (development or trusted internal networks only) | LOW (dev) / HIGH (prod) |
| `Transport` | TLS on the Kestrel endpoint (server-only or mutual) | LOW |
| `Message` | **UNSUPPORTED** — see §1.3 | HIGH |
| `TransportWithMessageCredential` | TLS + bearer token or client certificate | MEDIUM |

### 1.1 `SecurityMode.None`

gRPC can run over plaintext HTTP/2. This is acceptable only in controlled
internal environments (loopback IPC, intra-cluster traffic where the network
layer already provides encryption). In production, every gRPC endpoint must
use TLS — configure Kestrel with an HTTPS endpoint via `listenOptions.UseHttps(...)`.

### 1.2 `SecurityMode.Transport`

Maps to TLS configured at the Kestrel / IIS / HTTP.sys level; no application
code change is required for the transport layer, and the client uses an
`https://` channel address. For server-only TLS, standard Kestrel HTTPS
configuration is sufficient; for mutual TLS, see §3.2.

### 1.3 `SecurityMode.Message` — UNSUPPORTED (HIGH risk)

WCF message-level security uses WS-Security to encrypt and/or sign individual
SOAP message parts with XML Encryption/XML Signature. **gRPC and HTTP/2 have
no equivalent**, because gRPC frames binary Protobuf and relies on TLS at the
transport layer for confidentiality and integrity.

**Required redesign:**
- Replace message-level encryption with TLS and, where needed, mutual TLS.
- Replace message-level signing with a signed JWT (or an HMAC) carried in
  gRPC metadata.
- If confidentiality beyond TLS is required for regulatory reasons, evaluate
  application-level encryption of sensitive Protobuf `bytes` fields. This is
  an architectural decision that must be recorded and approved by the user.

**Regulatory note:** if message-level security exists for compliance reasons
(PCI-DSS, HIPAA, etc.), the compliance posture must be re-evaluated with the
user before migration proceeds.

### 1.4 `SecurityMode.TransportWithMessageCredential`

Commonly combines TLS transport with a WCF `MessageCredentialType` (for
example `UserName`, `Windows`, or `Certificate`). The transport layer maps to
TLS (§1.2); the credential type maps per §2 below.

---

## 2. Credential Type Mapping

| WCF `MessageCredentialType` / Transport Credential | gRPC Equivalent | Risk |
|-------------------------------------------------------|------------------|------|
| `None` | TLS only | LOW |
| `Windows` (NTLM / Kerberos) | **UNSUPPORTED** — see §2.1 | HIGH |
| `UserName` (username + password) | Credential exchanged for a bearer token, sent via the `Authorization` header | MEDIUM |
| `Certificate` | Mutual TLS client certificate | LOW–MEDIUM |
| `IssuedToken` (WS-Federation) | OAuth 2.0 / OIDC bearer token | MEDIUM |
| `CardSpace` | **UNSUPPORTED** — deprecated technology; no modern equivalent | HIGH |

### 2.1 Windows Authentication (NTLM / Kerberos) — UNSUPPORTED (HIGH risk)

`NetTcpBinding` and `WSHttpBinding` frequently use Windows Integrated
Authentication (NTLM or Kerberos/SPNEGO). **gRPC on ASP.NET Core does not
natively support NTLM or Kerberos negotiation over HTTP/2.**

**Required redesign** (architectural decision required); common replacement
strategies:
- **Microsoft Entra ID (formerly Azure AD):** issue short-lived JWT access
  tokens scoped to the gRPC service and validate them with the ASP.NET Core
  JWT Bearer authentication middleware. Suitable for internal and external
  consumers alike.
- **Active Directory Federation Services (AD FS) + OAuth 2.0:** federate
  existing Windows identities via OIDC to issue JWTs.
- **Negotiate/SPNEGO over HTTP/2:** experimental in some environments; not
  officially supported by ASP.NET Core gRPC and must not be assumed stable.

This is a **blocking** architectural decision — migration cannot proceed for
affected services until the user approves a replacement identity mechanism.

### 2.2 Certificate Authentication

Client certificates work naturally with gRPC because TLS negotiates the
certificate before any gRPC frame is processed. Configure Kestrel to require
client certificates, and add the
`Microsoft.AspNetCore.Authentication.Certificate` package for additional
validation (extended key usage, validity window, revocation). Access the
resolved `ClaimsPrincipal` via `ServerCallContext.GetHttpContext().User`.

**Risk: LOW–MEDIUM.**
- Certificates must be provisioned to every client, which can be
  operationally complex.
- Revocation checks (OCSP/CRL) require network access.

### 2.3 Bearer Tokens (JWT / OAuth 2.0 / OIDC)

The standard gRPC authentication pattern for both service-to-service and
user-to-service scenarios:

1. The client obtains a JWT from an identity provider.
2. The client sends the token as `Authorization: Bearer <token>` in gRPC
   call metadata.
3. The server validates it with ASP.NET Core JWT Bearer authentication.

```csharp
// Server: Program.cs
builder.Services.AddAuthentication()
    .AddJwtBearer(options => { /* configure authority and audience */ });

// Client: attach the token to each call
var headers = new Metadata { { "Authorization", $"Bearer {accessToken}" } };
await client.CallAsync(request, headers);
```

Use `CallCredentials` on the channel to inject the token automatically on
every call. Works with Microsoft Entra ID, IdentityServer, or any
standards-compliant OIDC provider.

**Risk: MEDIUM.** Requires identity-provider infrastructure where none
exists today.

---

## 3. Transport Security Configuration

### 3.1 Server TLS (Kestrel)

```json
// appsettings.json (production)
{
  "Kestrel": {
    "Endpoints": {
      "gRPC": {
        "Url": "https://0.0.0.0:5001",
        "Protocols": "Http2",
        "Certificate": { "Path": "cert.pfx", "Password": "..." }
      }
    }
  }
}
```

### 3.2 Mutual TLS (mTLS)

```csharp
builder.WebHost.ConfigureKestrel(options =>
{
    options.Listen(IPAddress.Any, 5001, listenOptions =>
    {
        listenOptions.Protocols = HttpProtocols.Http2;
        listenOptions.UseHttps(httpsOptions =>
        {
            httpsOptions.ClientCertificateMode =
                ClientCertificateMode.RequireCertificate;
        });
    });
});
```

### 3.3 TLS-Terminating Proxies

When a load balancer or reverse proxy (nginx, Envoy, Azure Application
Gateway) terminates TLS, traffic from the proxy to the application server
travels over plaintext HTTP/2. Acceptable only when the intra-cluster network
is trusted and the proxy enforces mTLS or IP allow-listing on the backend
leg. Configure ASP.NET Core to trust the proxy via `UseForwardedHeaders` and
`KnownProxies`.

---

## 4. Authorization

gRPC services use the standard ASP.NET Core authorization pipeline.

| WCF Mechanism | gRPC / ASP.NET Core Equivalent | Risk |
|------------------|--------------------------------|------|
| `PrincipalPermissionAttribute` | `[Authorize(Roles = "...")]` | LOW |
| `ServiceAuthorizationManager` | Custom `IAuthorizationHandler` | MEDIUM |
| Custom `IAuthorizationPolicy` | ASP.NET Core `AuthorizationPolicy` | MEDIUM |
| `ClaimsPrincipal` checks | Same API via `ServerCallContext.GetHttpContext().User` | LOW |
| Role-based (`WindowsIdentity`) | Claims-based via JWT role claims | MEDIUM |
| `AspNetCompatibilityRequirementsMode` | Not applicable; gRPC runs natively on ASP.NET Core | N/A |

Apply `[Authorize]` to the gRPC service class or to individual method
overrides, and read the authenticated principal via
`context.GetHttpContext().User` inside the service implementation.

---

## 5. WS-* Security Standards — Mostly UNSUPPORTED (HIGH risk)

| WS-* Standard | Status in gRPC |
|-----------------|-----------------|
| WS-Security | **UNSUPPORTED** |
| WS-SecureConversation | **UNSUPPORTED** |
| WS-Trust | **UNSUPPORTED** |
| WS-Federation | Replace with OIDC / OAuth 2.0 |
| WS-ReliableMessaging | **UNSUPPORTED** — see `error-and-streaming-mapping.md` §4 |
| WS-AtomicTransaction | **UNSUPPORTED** — see `error-and-streaming-mapping.md` §5 |
| WS-Addressing | Replaced by HTTP/2 headers and gRPC metadata |

Any WCF endpoint using WS-* security requires a full security redesign. This
is a HIGH-risk migration blocker that must be surfaced as an open decision
before specification authoring begins.

---

## 6. Secret and Certificate Management

WCF certificate and credential configuration commonly lives in `app.config`
or `web.config`. gRPC services should instead use:
- ASP.NET Core `IConfiguration` / `IOptions<T>` for runtime configuration.
- `X509Store` or a managed secret store (Azure Key Vault, HashiCorp Vault)
  for certificate and key material.
- Environment variables or a managed identity for credentials — never
  hardcode secrets in `.proto` files or source code.

---

## 7. Security Decision Checklist

The following must be answered in the decision log before the security
mapping is considered complete:

- [ ] What identity provider replaces Windows/Kerberos authentication?
- [ ] Is mTLS required for service-to-service calls?
- [ ] What is the access-token lifetime and refresh strategy?
- [ ] Are there compliance requirements (FIPS, HIPAA, PCI DSS) constraining
      cipher suites or key lengths?
- [ ] Which services are internal-only versus externally reachable?
- [ ] Is a coexistence period needed in which WCF (old auth) and gRPC (new
      auth) must run simultaneously?
