# WCF Discovery Patterns Reference

> **Scope:** Concrete, tool-agnostic signals and tracing recipes for finding
> and confirming every WCF construct the inventory records. Each pattern names
> *what to look for* and *how to confirm it beyond a raw match*. Apply these
> with whatever read-only search/file-reading capability is available. **A
> match is a candidate, not a conclusion** — always trace to implementation,
> configuration, and call sites before marking an item `complete`.

All searches are **read-only**. Never run commands that build, restore,
format, generate code, or otherwise mutate the working tree or global state.

---

## 0. Repository shape: server vs. client-only

| Signal | Indicates |
|--------|-----------|
| `ServiceHost`, `.svc` files, `[ServiceBehavior]`, `<system.serviceModel><services>` | Hosts services (server) |
| `ChannelFactory<`, `ClientBase<`, generated `Reference.cs`, `*.svcmap`, `<client><endpoint>` | Consumes services (client) |
| Both present | Server that also calls other WCF services |
| Only client signals, no service/host signals | **Client-only repository** |

Confirm `scope.serverMigration` and `scope.clientOnlyRepository` from the
*combination* of these signals, not a single hit. Record the evidence for each
boolean. Absence is a finding: "no `ServiceHost`, `.svc`, or `<services>`
element found in scope" supports `serverMigration: false`.

---

## 1. Solutions, projects, frameworks, packages

- **Solutions:** `*.sln`, `*.slnx`. Parse project references to build
  `SOL-*` → `PRJ-*` membership.
- **Projects:** `*.csproj`, `*.vbproj`. Read `TargetFramework(s)`,
  `TargetFrameworkVersion` (legacy), `OutputType`.
- **WCF references:**
  - Legacy: `<Reference Include="System.ServiceModel...">`,
    `System.ServiceModel.Web`, `System.Runtime.Serialization`.
  - SDK-style / .NET: `PackageReference` to `System.ServiceModel.*`
    (`Primitives`, `Http`, `NetTcp`, `Duplex`, `Federation`),
    `System.ServiceModel.Primitives`, `CoreWCF.*`, `protobuf-net`.
  - Tooling: `dotnet-svcutil`, `svcutil`, `Microsoft.Tools.ServiceModel`.
  - `packages.config` for legacy NuGet.
- **Confirm framework** from the project file, not from folder names. Record
  each target framework as a resolved string; use `unknown` when multi-target
  conditions or imported props obscure it.

---

## 2. Hosting topology

| Host kind | Signals to confirm |
|-----------|--------------------|
| IIS / WAS | `*.svc` (`ServiceHost` directive), `web.config` `<system.serviceModel>`, app-pool/site config, `global.asax` |
| Windows Service | `ServiceBase` subclass, `Installer`, `ServiceHost` opened in `OnStart` |
| Self-hosted console | `Main` that constructs `new ServiceHost(...)`, `host.Open()` |
| Desktop process | `ServiceHost` created inside a WinForms/WPF app |
| COM+ / hosted | `ServiceHostingEnvironment`, `EnableComPlusOnly` |
| Test host | `ServiceHost` in a test project, in-memory channel |

Trace each host to the concrete service type(s) it opens (constructor argument
or `<service name=...>`), and to its endpoints. Record entry point and
environment notes (installer, publish profile, Dockerfile, IIS metadata).

---

## 3. Service and operation contracts

- **Contracts:** `[ServiceContract]` on interfaces (usual) or classes. Capture
  `Name`, `Namespace`, `SessionMode`, `CallbackContract`, `ProtectionLevel`.
- **Operations:** `[OperationContract]`. Capture `IsOneWay`, `AsyncPattern`,
  `Action`/`ReplyAction`, `IsInitiating`/`IsTerminating`, `IsTerminating`, and
  the declared `[FaultContract(typeof(...))]`.
- **Callback contracts (duplex):** `CallbackContract = typeof(...)` on
  `[ServiceContract]`; the callback interface's `[OperationContract]` members.
  Duplex callback → `shape: duplex-callback` (HIGH risk).
- **Streaming:** parameters/returns of type `Stream`, `Message`, or
  `TransferMode.Streamed`/`StreamedRequest`/`StreamedResponse` on the binding →
  server/client streaming shapes.
- **One-way:** `IsOneWay = true` → `shape: one-way`.
- **Instance/concurrency:** `[ServiceBehavior(InstanceContextMode=...,
  ConcurrencyMode=...)]` and matching config; also `[CallbackBehavior]`.

**Trace, do not stop at attributes:**
1. From the contract interface, find the implementing class
   (`class X : IContract`) → `implementationSymbols`.
2. From the implementation/host, find endpoints exposing it (config or code).
3. From consumers, find call sites (proxy or `ChannelFactory`).
Only when all three are established may the operation/service be `complete`.

---

## 4. Data, message, and fault contracts

| Construct | Signals |
|-----------|---------|
| Data contract | `[DataContract]` + `[DataMember(Name, Order, IsRequired, EmitDefaultValue)]` |
| Non-serialized member | `[IgnoreDataMember]` |
| Enum | `[DataContract]`/`[EnumMember]`, or plain enum used in a contract |
| Message contract | `[MessageContract]`, `[MessageHeader]`, `[MessageBodyMember]` |
| Fault contract | `[FaultContract(typeof(T))]` on operations; the fault detail type |
| Inheritance/polymorphism | `[KnownType(typeof(T))]`, `[ServiceKnownType]`, base-type `[DataContract]`, `[XmlInclude]` |
| Serializer choice | `[XmlSerializerFormat]`, `[DataContractFormat]`, `[DataContractSerializer]` vs. `NetDataContractSerializer`, `protobuf-net` attributes |

**Serialization-sensitive fields to flag as risks:** `decimal`,
`DateTime`/`DateTimeOffset`/`TimeSpan` (time-zone and precision semantics),
`Guid`, `byte[]`, `Dictionary<,>`/`Hashtable`, nullable vs. non-nullable value
types, `EmitDefaultValue=false` (presence semantics), explicit `Order`
dependence, and XML namespace/order-sensitive `[MessageContract]`s. Record the
`.NET` type, `nullable`, `required`, `emitDefaultValue`, and `order` per field.

---

## 5. Endpoints, bindings, behaviors, configuration

### 5.1 Configuration files

- `web.config`, `app.config`, and machine/root config overrides.
- Config transforms: `Web.<Environment>.config`, `App.<Environment>.config`,
  and XDT `xdt:Transform`/`xdt:Locator` attributes. Record which values are
  environment-specific and set each `setting.source` accordingly.
- Sections: `<system.serviceModel>` → `<services>`, `<client>`, `<bindings>`,
  `<behaviors>` (`<serviceBehaviors>`, `<endpointBehaviors>`), `<diagnostics>`,
  `<protocolMapping>`, `<standardEndpoints>`.

### 5.2 Endpoints and bindings

- `<service name=...>` → `<endpoint address binding bindingConfiguration
  contract>`. Also `<host><baseAddresses>`.
- Bindings: `basicHttpBinding`, `wsHttpBinding`, `netTcpBinding`,
  `netNamedPipeBinding` (named pipes — HIGH risk), `netMsmqBinding` (MSMQ —
  HIGH risk), `ws2007HttpBinding`, `wsDualHttpBinding` (duplex),
  `webHttpBinding`, custom `<customBinding>`.
- Binding settings to capture: `openTimeout`, `closeTimeout`, `sendTimeout`,
  `receiveTimeout`, `maxReceivedMessageSize`, `maxBufferSize`,
  `maxBufferPoolSize`, `<readerQuotas>`, `messageEncoding`, `transferMode`,
  `<reliableSession>` (ordered/enabled — HIGH risk), `transactionFlow`.

### 5.3 Code-based configuration

Not everything is in XML. Also inspect code:
- `new ServiceHost(...)`, `host.AddServiceEndpoint(...)`,
  `host.Description.Behaviors.Add(...)`.
- `new ChannelFactory<T>(binding, address)`, `new BasicHttpBinding{...}` with
  properties set in code.
- `ServiceBehaviorAttribute`, `[ServiceThrottling]`, code-set `readerQuotas`.
Record `setting.source: code` for values only present in code.

### 5.4 Throttling / quotas / behaviors

- `<serviceThrottling maxConcurrentCalls/Sessions/Instances>`.
- `<serviceMetadata>`, `<serviceDebug includeExceptionDetailInFaults>`
  (security-sensitive), `<serviceCredentials>`, `<dataContractSerializer
  maxItemsInObjectGraph>`.

---

## 6. Security and identity

| Concern | Signals |
|---------|---------|
| Security mode | binding `security mode` = `None`/`Transport`/`Message`/`TransportWithMessageCredential`/`TransportCredentialOnly` |
| Credential type | `clientCredentialType` = `Windows`/`Certificate`/`UserName`/`IssuedToken`/`Ntlm`/`Basic` |
| WS-* federation | `wsFederationHttpBinding`, `<issuedToken>`, STS references (HIGH risk) |
| Windows auth | `Windows` credentials, `PrincipalPermission`, `WindowsIdentity`, impersonation (`[OperationBehavior(Impersonation=...)]`) |
| Certificates | `<serviceCertificate>`, `<clientCertificate>`, `X509` findValue/thumbprint — **redact values** |
| Authorization | `[PrincipalPermission]`, `ServiceAuthorizationManager`, role providers, `<authorization>` |
| Identity | `<endpoint><identity>` (dns/upn/spn) |

Never copy thumbprints, passwords, or connection strings into the inventory.
Cite the location and redact the value.

---

## 7. Extensibility points (gRPC interceptor/middleware analogues)

| WCF extension | Signals |
|---------------|---------|
| Message inspectors | `IDispatchMessageInspector`, `IClientMessageInspector` |
| Parameter inspectors | `IParameterInspector` |
| Error handling | `IErrorHandler`, `IServiceBehavior` adding error handlers, `FaultException`/`FaultException<T>` throw sites |
| Custom behaviors | `IServiceBehavior`, `IEndpointBehavior`, `IOperationBehavior`, `IContractBehavior`, `BehaviorExtensionElement` |
| Encoders / bindings | `MessageEncoder`, `MessageEncoderFactory`, custom `Binding`/`BindingElement` |
| Instance providers | `IInstanceProvider`, `IInstanceContextProvider` |

These map later to gRPC interceptors/middleware; record them so the mapping
stage can plan equivalents.

---

## 8. Consumers and generated clients

| Consumer kind | Signals |
|---------------|---------|
| Generated proxy | `*.svcmap`, `Reference.cs`/`Reference.svcmap`, `[System.CodeDom.Compiler.GeneratedCode]`, `ClientBase<T>` subclasses, `dotnet-svcutil` output |
| Hand-written proxy | `ChannelFactory<T>` creation and `.CreateChannel()` |
| Config client | `<client><endpoint>` entries |
| Internal caller | Project references to the contracts assembly + call sites |
| External controlled | Known internal repos/teams that call the service |
| External uncontrolled | Third parties, unknown SOAP callers (coexistence risk) |

Trace consumers to services via actual **call sites** (`proxy.Operation(...)`,
`channel.Operation(...)`), not by matching names. Record `upgradeControl`
(who can change the caller) and `generatedClient`. In a client-only
repository, consumers and their consumed endpoints/bindings are the primary
inventory content.

---

## 9. External dependencies, deployment, tests

- **Dependencies:** connection strings (databases — **redact**), MSMQ queue
  paths, identity providers/STS, certificate stores, file shares, downstream
  SOAP/gRPC/REST services. Link `affectedIds`.
- **Deployment:** IIS site/app-pool config, `*.pubxml` publish profiles,
  `ServiceInstaller`, MSI/WiX, Dockerfiles, Helm/K8s manifests, CI/CD YAML.
- **Tests:** projects referencing test frameworks (`xunit`, `nunit`,
  `mstest`) that exercise contracts/operations; integration tests that open a
  `ServiceHost` or call a proxy. Inventory them as parity-baseline candidates.
  **Do not execute** tests or tools if running them mutates state.

---

## 10. Anti-patterns to avoid

- Concluding a service is fully mapped from a single `[ServiceContract]` hit.
- Reading only `web.config` and missing code-based `ChannelFactory`/binding
  configuration (or vice versa).
- Treating environment-transform values as base values.
- Matching consumers to services by name instead of tracing call sites.
- Recording an unknown as an empty string, `0`, `null`, or a plausible guess.
- Copying secrets into evidence.
- Claiming `analysisState: complete` or runtime parity from static reads.
