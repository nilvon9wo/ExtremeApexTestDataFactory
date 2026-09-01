# Roadmap: Serialization-Based Mock Enrichment

Status: **📋 proposed, not built.** A cluster of test conveniences that all need
the one thing the SObject API cannot do in memory — write a field or
relationship that `record.put(...)` rejects — via a `JSON.serialize` /
`deserialize` round-trip (the technique in Nebula's `TestingUtils` / the
`XAP_TEST_ReadOnlyHelper` the project has floated: `setReadOnlyField`,
`setParentRelationships`, `setChildRelationships`).

All of it is opt-in, for `MOCK` / `NEVER` graphs (or a `DEFERRED` graph after
`flush()`). None is core, and the serialization cost is the reason it may stay
proposed.

---

## The shape: one method on the bundle

Rather than several builder methods, hang the whole feature off the finished
bundle:

```apex
XFTY_DummySObjectBundle enriched = bundle.getWithInjectedValues(config);
```

- **Terminal by construction.** It operates on an already-generated graph and
  returns a **new** bundle of new instances — the original bundle (and the
  instances `DEFERRED` back-fills Ids onto) is untouched. This sidesteps the
  instance-identity problem that rules out doing any of this as a value pass
  during generation.
- **The consumer describes exactly what to materialise.** A real SOQL query
  returns a specific, bounded set of ancestor levels and child subqueries; the
  config is the same idea — a declared list of relationship paths and forced
  values. Nothing is injected that was not asked for, so "inject everything",
  circular `a.Parent.Children[0].Parent…` structures, and unbounded cost are
  all avoided by design.

### `XFTY_InjectionConfig` (sketch)

```apex
XFTY_InjectionConfig config = new XFTY_InjectionConfig()
    // materialise a parent object, any depth - mirrors Account, Account.Owner in a SELECT
    .populate(new List<SObjectField>{ Contact.AccountId })
    .populate(new List<SObjectField>{ Contact.AccountId, Account.OwnerId })
    // materialise a child subquery at a point on the path
    .populateChildren(new List<SObjectField>{ Contact.AccountId }, Case.AccountId)   // contact.Account.Cases
    // force a read-only / system / formula value on the record at a path
    .forceValue(new List<SObjectField>{}, Contact.CreatedDate, aDatetime)
    .forceValue(new List<SObjectField>{ Contact.AccountId }, Account.LastModifiedById, aUserId);
```

Exact config API is an open question; the point is that it is one declarative
object, not scattered flags.

---

## What the bundle already knows

The graph is all there — the enrichment pass only re-expresses it in the shape
`put` cannot produce.

| Injection | Source in the bundle |
|---|---|
| parent object (`contact.Account`, `contact.Account.Owner`) | `getList(relField)[i]`, recursed via `getBundle(relField)` |
| forced read-only value | supplied in the config |
| child subquery on a `withChildren` collection (`account.Contacts`) | `childRecordsOf(i, childField)` |
| child subquery on a **generated ancestor** (`account.Contacts` where the Account was generated *because* a Contact asked for it) | the inverse of the 1:1 parent alignment — primary row `i`'s generated Account has child `[Contact i]`; a [shared ancestor](../use/shared-ancestors.md) has the several children that resolved to it |

That last row corrects an earlier claim here: upward generation **does** give an
ancestor children — every generated parent has at least the record that
generated it. XFTY does not expose that inverse view as a clean accessor yet
(only `childRecordsOf`, for `withChildren`); the enrichment pass would need one.

The child-relationship *name* for a subquery comes from the parent side — walk
`SObjectType.getDescribe().getChildRelationships()`, match on `getField()`, take
`getRelationshipName()` (`Contacts`, `Cases`, `Foo__r`).

---

## Caveats (all of it)

- **`MOCK` / `NEVER` only**, or a `DEFERRED` bundle after `flush()` — call it
  before flush and the injected copies never get Ids.
- **Not visible to generation.** A forced read-only value or injected
  relationship cannot feed a [context-aware value](../use/context-aware-values.md);
  the pass runs after generation is over. (A read-only value on an uninserted
  record is fiction anyway.)
- **Snapshot semantics.** An injected subquery / parent is a fixed copy. Code
  under test that mutates it and expects re-query behaviour will not see the
  change.
- **Cost.** One serialize + deserialize per enriched record, multiplied by the
  paths asked for. It is opt-in and the config bounds it, but a deep config over
  a large graph is not cheap.
- **Provider surface untouched.** `getWithInjectedValues` is on the bundle, not
  on `XFTY_DummySObjectMasterTemplate` / `XFTY_SObjectChildProvider`, so a
  Provider still cannot emit a non-insertable record — "Provider records are
  always insertable" holds.
- **Using it flags the test as `MOCK`-only** — see
  [unit-vs-integration.md](../use/advanced/unit-vs-integration.md) point 4.
- A shipped version needs tests around JSON quirks — datetime formatting,
  `Blob` fields, compound `Location` fields, the required `attributes.type` on
  deserialize, the `{ totalSize, done, records }` subquery envelope.

---

## Open questions

- The `XFTY_InjectionConfig` API shape — paths as `List<SObjectField>`? A small
  builder? How are forced values scoped to a record on a path?
- Does the enrichment pass need a first-class "children of a generated ancestor"
  accessor on the bundle, and is that useful on its own (independent of
  serialization)?
- Is this common enough to justify the surface, or do most consumers navigate
  relationships rarely enough that reading straight off the bundle suffices?
- Block (throw) when called on a `NOW` / `RELATED_ONLY` bundle, or no-op with a
  warning?
