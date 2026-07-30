# Protobuf Type and Serialization Mapping Reference

> **Scope:** Mapping from WCF/.NET data-contract types to proto3 types and
> well-known types, with wire-format implications, nullability/zero-value
> differences, and required custom message definitions. Risk levels follow
> `feature-mapping.md`. See `sources.md` for citations.

---

## 1. Proto3 Scalar Type Table

| .NET / WCF Type | proto3 Type | Notes |
|------------------|------------|-------|
| `bool` | `bool` | Default `false`; not nullable without `optional` |
| `int` / `Int32` | `int32` | Default `0`; negative values cost 5 bytes (consider `sint32`) |
| `uint` / `UInt32` | `uint32` | Default `0` |
| `long` / `Int64` | `int64` | Default `0` |
| `ulong` / `UInt64` | `uint64` | Default `0` |
| `float` | `float` | 32-bit IEEE 754 |
| `double` | `double` | 64-bit IEEE 754 |
| `string` | `string` | UTF-8; default empty string `""` |
| `byte[]` | `bytes` | Default empty bytes |
| `short` / `Int16` | `int32` | proto3 has no 16-bit type; truncate/validate range in code |
| `byte` / `sbyte` | `int32` | Same; validate range in service code |
| `char` | `string` (length 1) or `uint32` (code point) | Requires an explicit decision |

---

## 2. Nullable and Zero-Value Semantics

**This is one of the highest-risk serialization areas.** A proto3 implicit
(non-`optional`) scalar field cannot distinguish "not set" from "set to its
zero value" (`0`, `false`, `""`). WCF `[DataMember]` fields, by contrast, can
be genuinely `null`.

### 2.1 Recommended approach

Use the `optional` keyword on any scalar field where WCF code checks for
`null` or requires presence detection:

```protobuf
message Order {
  optional int32 quantity = 1;   // generates HasQuantity() / ClearQuantity()
  optional string reference = 2; // distinguishable from empty string
}
```

`optional` fields generate `Has<FieldName>()` and `Clear<FieldName>()`
methods in the C# output, enabling null-equivalent checks.

### 2.2 Well-known wrapper types (legacy)

`google.protobuf.Int32Value`, `google.protobuf.StringValue`, and similar
wrapper types predate the `optional` keyword and are now considered obsolete
for new designs; prefer `optional` scalars. Wrapper types remain relevant
only for wire compatibility with systems that already use them.

### 2.3 Migration risk

Any WCF data-contract field that:
- is a nullable value type (`int?`, `bool?`, `DateTime?`, etc.), **or**
- sets `EmitDefaultValue = false` on `[DataMember]`, **or**
- is checked for `null` in business logic

must be mapped to an `optional` proto3 field. Omitting this causes silent
data corruption whenever a legitimate zero value is indistinguishable from
"absent."

**Risk: HIGH if overlooked; LOW once identified and marked `optional`.**

---

## 3. Date and Time Types

### 3.1 `DateTime` / `DateTimeOffset` → `google.protobuf.Timestamp`

```protobuf
import "google/protobuf/timestamp.proto";

message Event {
  google.protobuf.Timestamp occurred_at = 1;
}
```

`Timestamp` represents a UTC point in time as seconds + nanoseconds since the
Unix epoch. The C# generated type exposes `.ToDateTime()` and
`.ToDateTimeOffset()` via `Google.Protobuf.WellKnownTypes.Timestamp`.

**Risk: MEDIUM.**
- WCF `DateTime` values may carry `DateTimeKind.Local` or `Unspecified`; all
  values must be normalized to UTC before serialization.
- `DateTimeOffset` carries a UTC offset that `Timestamp` does not; if the
  consumer needs the offset, add a separate field (e.g., `string utc_offset`
  formatted as `"+05:30"`).
- Any service that persists or compares `DateTime` values must apply
  consistent UTC normalization end to end.

### 3.2 `TimeSpan` → `google.protobuf.Duration`

```protobuf
import "google/protobuf/duration.proto";

message SlaConfig {
  google.protobuf.Duration timeout = 1;
}
```

`Duration` is seconds + nanoseconds and may be negative. Use `.ToTimeSpan()`
in the C# generated code.

**Risk: LOW.**

---

## 4. `decimal`

Protobuf has no built-in decimal type. This is a **HIGH**-risk area for
financial or scientific data.

**Options (decision required from the user):**

| Option | Pros | Cons |
|--------|------|------|
| `string` | Lossless; human-readable | Serialization overhead; parsing required on both ends |
| Custom `DecimalValue { int64 units; sfixed32 nanos; }` message | Compact; typed | Requires shared encode/decode helpers for every consumer |
| `double` | Simple | Floating-point rounding error; **not safe for currency** |

Microsoft's official gRPC-for-WCF-developers guidance recommends a custom
`DecimalValue` message (units + nanos) for monetary values, defined once in a
shared `.proto` file and referenced across services:

```protobuf
// shared/decimal.proto
message DecimalValue {
  // Whole-number part (may be negative).
  int64 units = 1;
  // Fractional part: value = units + nanos / 10^9.
  // Must be in the range [0, 999_999_999].
  sfixed32 nanos = 2;
}
```

**Risk: HIGH.** Every decimal field requires explicit encode/decode helpers
and end-to-end tests covering negative, zero, and large values.

---

## 5. GUID / `Guid`

proto3 has no native GUID type.

| Option | Notes |
|--------|-------|
| `string` (canonical `xxxxxxxx-xxxx-…` form) | Human-readable; 36 bytes on the wire |
| `bytes` (16 raw bytes) | Compact; endian-sensitive |

**Recommendation:** use `string` unless payload size is critical; agree on a
canonical format (lowercase, no braces) and validate at service boundaries.

**Risk: LOW–MEDIUM** (endian handling if `bytes` is chosen).

---

## 6. Enumerations

WCF enums serialized via `[DataMember]` map directly to proto3 `enum`:

```protobuf
enum OrderStatus {
  ORDER_STATUS_UNSPECIFIED = 0; // proto3 requires a zero-value member
  ORDER_STATUS_PENDING = 1;
  ORDER_STATUS_SHIPPED = 2;
  ORDER_STATUS_CANCELLED = 3;
}
```

**Risk: MEDIUM.**
- proto3 requires field number `0` for the first enum value. If the WCF enum
  has no zero-value member, or its zero member carries business meaning, add
  an explicit `UNSPECIFIED = 0` sentinel and verify no code depends on
  default-zero semantics.
- proto3 allows unknown enum values to round-trip; consumers must handle
  unrecognized values gracefully.
- Rename WCF `PascalCase` members to `SCREAMING_SNAKE_CASE` with a type
  prefix, per Protobuf style conventions.

---

## 7. Collections

| WCF / .NET Type | proto3 Type | Notes |
|-------------------|------------|-------|
| `T[]` / `List<T>` / `IList<T>` | `repeated T` | Order preserved; may be empty |
| `IEnumerable<T>` | `repeated T` | Enumerate fully before serializing |
| `Dictionary<K,V>` | `map<K, V>` | Key must be integral, `bool`, or `string` |
| `SortedDictionary<K,V>` | `map<K, V>` | proto3 maps have no ordering guarantee |
| `HashSet<T>` | `repeated T` (deduplicate in code) | No native set type |
| `Queue<T>` / `Stack<T>` | `repeated T` (ordering by convention) | No native queue/stack type |

Nested collections (e.g., `List<List<T>>`) are not directly supported; wrap
the inner list in a message:

```protobuf
message IntList { repeated int32 values = 1; }
message Matrix   { repeated IntList rows = 1; }
```

**Risk: LOW** for simple lists; **MEDIUM** for nested or keyed collections.

---

## 8. Inheritance and Polymorphism

WCF uses `[KnownType]` for polymorphic data contracts. Proto3 has no message
inheritance.

### 8.1 `oneof` for closed polymorphism

Use when the set of concrete types is known at design time:

```protobuf
message Animal {
  oneof kind {
    Dog dog = 1;
    Cat cat = 2;
    Bird bird = 3;
  }
}
```

Only one field of a `oneof` is set at a time.

### 8.2 `google.protobuf.Any` for open polymorphism

Use when subtypes may be added without recompiling the parent schema:

```protobuf
import "google/protobuf/any.proto";

message Event {
  google.protobuf.Any payload = 1;
}
```

`Any` carries a type URL plus serialized bytes; both sides must share a type
registry. This is flexible but sacrifices strong typing and adds overhead.

**Risk: HIGH.** The shape of the polymorphic hierarchy must be fully
understood before choosing `oneof` vs. `Any` — changing the choice later is
a breaking wire change.

---

## 9. XML-Specific Constructs

WCF supports `XmlElement`, `XmlDocument`, and `IXmlSerializable` types, which
have no proto3 representation.

**Options:**
- Serialize as a `string` containing XML text — lossless but opaque to
  Protobuf tooling.
- Refactor to strongly typed Protobuf messages — recommended for new
  contracts.

**Risk: HIGH** for any contract carrying raw XML; requires an architectural
decision on whether to preserve or replace the XML payload.

---

## 10. Large Payloads and Streaming

| WCF Feature | gRPC Equivalent | Notes |
|--------------|------------------|-------|
| `TransferMode.Streamed` | gRPC client/server/bidirectional streaming | See `error-and-streaming-mapping.md` §2 |
| `TransferMode.Buffered` (large single message) | Raise `MaxReceiveMessageSize` / `MaxSendMessageSize` | Default gRPC limit is 4 MB |
| MTOM binary attachments | `bytes` field, or streaming | MTOM has no gRPC equivalent |

**Risk: MEDIUM** for large messages; **HIGH** for MTOM.

---

## 11. Serializer Compatibility

WCF uses `DataContractSerializer` or `XmlSerializer`; gRPC uses Protobuf
binary encoding. These are not wire-compatible, and there is no automatic
adapter between them.

Key implications:
- Existing WCF message logs cannot be replayed against gRPC services.
- `DataContract` blobs stored in databases must be migrated or dual-read
  during the coexistence period.
- `[DataMember(Order = ...)]` XML ordering has no equivalent; Protobuf uses
  field numbers.
- `DataMember.Name` overrides are dropped; JSON transcoding uses the
  Protobuf field name instead.

**Risk: MEDIUM–HIGH** for any system that persists serialized WCF messages.

---

## 12. Field Numbering Policy

Protobuf field numbers are **permanent and must never be reused** once
published. Rules enforced by this plugin:

1. Assign numbers 1–15 to the most frequently populated fields (1-byte
   varint encoding).
2. When a field is removed, add its number and name to `reserved`.
3. Regenerating specs must never renumber an existing field.
4. New fields on an existing message must use numbers that were never
   previously assigned or reserved.

```protobuf
message Order {
  reserved 3, 4, 7;
  reserved "legacy_status";
  string id = 1;
  string customer_id = 2;
  // fields 3, 4, 7 were removed in v1.1
}
```
