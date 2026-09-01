# Roadmap: Serialization-Based Mock Enrichment

Status: **📋 proposed, not built.** A cluster of test conveniences that all need
the one thing the SObject API cannot do in memory — write a field or
relationship that `record.put(...)` rejects — via a `JSON.serialize` /
`deserialize` round-trip (the technique in Nebula's `TestingUtils` / the
`XAP_TEST_ReadOnlyHelper` the project has floated: `setReadOnlyField`,
`setParentRelationships`, `setChildRelationships`).

It is one opt-in method on the finished bundle. None of it is core, and the
serialization cost is the reason it may stay proposed.

---

## The shape: one method on the bundle

```apex
XFTY_DummySObjectBundle enriched = bundle.getWithInjectedValues(config);
```

- **Terminal by construction.** It operates on an already-generated graph and
  returns a **new** bundle of new instances — the original bundle (and the
  instances `DEFERRED` back-fills Ids onto) is untouched. This sidesteps the
  instance-identity problem that rules out doing any of this as a value pass
  during generation.
- **Insert mode is not policed.** Because it is a read-off-the-bundle
  operation, it works after any mode. `NOW` is an odd pairing (you could just
  `SELECT`) but it is the developer's call. Under `DEFERRED` **before**
  `flush()` the data is thin (no Ids, FKs only partly wired) — that case logs a
  warning rather than failing.
- **The consumer declares exactly what to materialise.** The config is a
  bounded, declared list — nothing is injected that was not asked for, so
  "inject everything", circular `a.Parent.Children[0].Parent…` structures, and
  unbounded cost are avoided by design.

### `XFTY_InjectionConfig` (sketch)

Three maps keyed by **path** — a `List<SObjectField>` giving a location relative
to the primary record (`{}` = the primary itself, `{ Contact.AccountId }` = its
Account, `{ Contact.AccountId, Account.OwnerId }` = that Account's Owner):

```apex
XFTY_InjectionConfig config = new XFTY_InjectionConfig()
    // 1. values to write - the value is anything that can feed a master template
    //    (an exact value, XFTY_DummyDefaultValueIntf, ...)
    .value(new List<SObjectField>{}, Contact.CreatedDate, aDatetime)
    .value(new List<SObjectField>{ Contact.AccountId }, Account.LastModifiedById, new SomeUserIdProvider())
    // 2. parents to materialise as relationship objects
    .parent(new List<SObjectField>{ Contact.AccountId })                 // contact.Account
    .parent(new List<SObjectField>{ Contact.AccountId, Account.OwnerId }) // contact.Account.Owner
    // 3. children to materialise as subqueries
    .children(new List<SObjectField>{}, Case.ContactId)                   // contact.Cases
    .children(new List<SObjectField>{ Contact.AccountId }, Case.AccountId); // contact.Account.Cases
```

Internally: `Map<path, valueProviderByField>`, `Map<path, Set<parentField>>`,
`Map<path, Set<childField>>`.

**Convenience methods** for the common cases so most configs are one or two
lines: exact value on a root field; a named root parent or root child; *all*
root parents; *all* root children.

### The SOQL-shape safety check

By **default the config may only describe a result a single SOQL statement
could return** — pure ancestor chains, one level of child subquery (no nested
subqueries), children that actually reference their parent. This is both a
safety rail (an injected shape the platform could never produce is a landmine
in an integration test) and a scope limit on what has to be implemented.

`config.allowNonQueryableShapes()` turns the check off. Past that point it is on
the developer to describe something XFTY can make sense of.

---

## What the bundle already knows

The graph is all there — the enrichment pass only re-expresses it in the shape
`put` cannot produce.

| Injection | Source in the bundle |
|---|---|
| parent object (`contact.Account`, `contact.Account.Owner`) | `getList(relField)[i]`, recursed via `getBundle(relField)` |
| forced value | supplied in the config |
| child subquery on a `withChildren` collection (`account.Contacts`) | `childRecordsOf(i, childField)` |
| child subquery on a **generated ancestor** (`account.Contacts` where the Account was generated *because* a Contact asked for it) | the inverse of the 1:1 parent alignment — primary row `i`'s generated Account has child `[Contact i]`; a [shared ancestor](../use/shared-ancestors.md) has the several children that resolved to it |

That last row corrects an earlier claim here: upward generation **does** give an
ancestor children — every generated parent has at least the record that
generated it. The pass has to compute that inverse (which primaries point at a
given generated ancestor) from the alignment; today only `childRecordsOf`
exists, and only for `withChildren`. Whether that inverse view is also worth a
public bundle accessor in its own right is secondary.

The child-relationship *name* for a subquery comes from the parent side — walk
`SObjectType.getDescribe().getChildRelationships()`, match on `getField()`, take
`getRelationshipName()` (`Contacts`, `Cases`, `Foo__r`).

---

## Caveats

- **Not visible to generation.** A forced value or injected relationship cannot
  feed a [context-aware value](../use/context-aware-values.md); the pass runs
  after generation is over. (A read-only value on an uninserted record is
  fiction anyway.)
- **Snapshot semantics.** An injected subquery / parent is a fixed copy. Code
  under test that mutates it and expects re-query behaviour will not see the
  change.
- **Cost.** One serialize + deserialize per enriched record, multiplied by the
  paths asked for. The config bounds it, but a deep config over a large graph is
  not cheap.
- **`DEFERRED` before `flush()`** gives thin data — warned, not blocked.
- **Provider surface untouched.** `getWithInjectedValues` is on the bundle, not
  on `XFTY_DummySObjectMasterTemplate` / `XFTY_SObjectChildProvider`, so a
  Provider still cannot emit a non-insertable record.
- **Using it flags the test as `MOCK`-only** — see
  [unit-vs-integration.md](../use/advanced/unit-vs-integration.md) point 4.
- A shipped version needs tests around JSON quirks — datetime formatting,
  `Blob` fields, compound `Location` fields, the required `attributes.type` on
  deserialize, the `{ totalSize, done, records }` subquery envelope.

---

## Open questions

- Final `XFTY_InjectionConfig` API — the three maps and the exact convenience
  set.
- How a path element is read as "up" vs "down" (the field's own type vs the type
  it references), and whether the three separate maps make that unambiguous.
- Does the "children of a generated ancestor" inverse deserve a public bundle
  accessor, independent of this feature?
- Is this common enough to justify the surface, or do most consumers navigate
  relationships rarely enough that reading straight off the bundle suffices?
