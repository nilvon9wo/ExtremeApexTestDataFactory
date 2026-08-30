# Design: Multi-Variant Providers

Status: **implemented** on the `multi-variant-providers` branch, then revised.
The rest of this document is the design record; where things ended up:

- **`keyFor` → `keysFor`** (returns `Set<XFTY_LookupKeyIntf>` - a record can match
  several variants). `XFTY_LookupKeys.resolve` picks the most specific via
  `XFTY_LookupKeyIntf.getSpecificity()`; an equally-specific tie is an error.
- **`XFTY_FlavorLookupKey` → `XFTY_FlavouredLookupKey`**: `SObjectType` + optional
  record type + arbitrary `XFTY_SObjectPredicateIntf` conditions
  (`XFTY_FieldPredicate` ships the common ones). It is not flyweighted (carries
  behaviour); the lookup still dedupes by hash.
- **`XFTY_RecordTypeLookupKeyIntf extends XFTY_LookupKeyIntf`** so the lookup can
  ask any record-type-bearing key for its developer name / Id.
- **`XFTY_RecordTypeDataProvider`** rebuilt as a one-SOQL repository of all record
  types.

Earlier deviations from the original proposal:

- **No inheritance.** `@IsTest` classes cannot be abstract or virtual, so
  `XFTY_AbstractSObjectProviderLookup` became a concrete, *composed*
  `XFTY_DefaultSObjectProviderLookup` (configure it, don't extend it), and
  `XFTY_RecordTypeLookupKey` / `XFTY_FlavorLookupKey` wrap an `XFTY_LookupKey`
  instead of subclassing it.
- **Keys are flyweights.** Obtain them with `XFTY_LookupKey.get(...)` etc.;
  constructors are private and instances are interned.
- **Deferred + memoised key resolution**, as proposed:
  `XFTY_DummyDefaultRelationshipIntf.resolveLookupKey(lookup)`.
- **`Required` + `Optional` merged** into `XFTY_DummyDefaultRelationship`;
  requiredness moved to the Master Template slot
  (`putRequired` / `putOptional`; untyped `put` ⇒ required).
- **`XFTY_FlavorLookupKey`** shipped alongside `XFTY_RecordTypeLookupKey`.
- `XFTY_DefaultSObjectProviderLookup.register` has a `(key, providerInstance)` overload
  for Providers that need constructor arguments (and for tests).
- `XFTY_DefaultAccountDataProvider` was **not** rewritten as a Person/Business
  example (scratch orgs lack Person Accounts); `XFTY_MultiVariantProviderTest`
  is the worked example instead.

---

## Goal

Resolve a Provider by more than `SObjectType`. The motivating case is Business
Account vs Person Account, where one `SObjectType` needs two genuinely different
Master Templates. More generally: `SObjectType (+ RecordType) (+ Flavor)`, where
*Flavor* is an arbitrary discriminator chosen by the developer.

Today `XFTY_DummySObjectProviderLookupIntf.get(SObjectType)` allows exactly one
Provider per type, and `XFTY_DefaultAccountDataProvider` works around this with a
commented-out `createBundle` branch that inspects `RecordTypeId`.

---

## The lookup key

```apex
public interface XFTY_LookupKeyIntf {
    SObjectType getSObjectType();
    Boolean isInstanceOf(SObject sObj);   // does this record belong to this variant?
    String getHashKey();                  // value-equality identity for Map storage
}
```

`getHashKey()` (rather than `equals`/`hashCode`) keeps `Map` storage boring and
debuggable: implementations are stored in a `Map<String, ...>` keyed by hash key,
so two *different instances* describing the *same variant* collide correctly.

Shipped implementations:

| Class | Hash key | `isInstanceOf` |
|-------|----------|----------------|
| `XFTY_LookupKey` | `Account` | record is of that `SObjectType` |
| `XFTY_RecordTypeLookupKey` | `Account::PersonAccount` | type matches **and** `RecordTypeId` resolves to that developer name |

Each has two constructors: `(SObjectType, ...discriminator)` for explicit use and
`(SObject)` to derive the discriminator from a record (`RecordTypeId` for the
record-type key). *Flavor* is not derivable from a record, so a flavor key is a
user-written `XFTY_LookupKey` subclass with its own discriminator field and is
only ever used explicitly.

---

## Where key resolution happens — the main design decision

The tricky part the sketch identified: `new XFTY_DummyDefaultRelationshipRequired(new Account(...))`
needs to know *which variant* of Account to generate, but at construction time it
has no idea what variants are registered.

**Resolution is deferred to the factory, which has the lookup.** A relationship
template stores an *optional* explicit `XFTY_LookupKeyIntf` plus the `SObject`
override template. When the factory processes it:

```apex
XFTY_LookupKeyIntf key = relationship.getExplicitKey();
if (key == null) {
    key = lookup.keyFor(relationship.getOverrideTemplate());
}
XFTY_DummySobjectProviderIntf provider = lookup.get(key);
```

`lookup.keyFor(sObj)` walks the lookup's registered keys, returns the first whose
`isInstanceOf(sObj)` is true, and falls back to `new XFTY_LookupKey(sObj.getSObjectType())`.
This means the "known options" problem is solved by the component that actually
knows the options, and no reflection / describe-scanning is needed at
construction time.

---

## Interface changes

```apex
public interface XFTY_DummySObjectProviderLookupIntf {
    XFTY_DummySobjectProviderIntf get(SObjectType sObjectType);   // BC — delegates to get(new XFTY_LookupKey(type))
    XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf key);
    XFTY_LookupKeyIntf keyFor(SObject sObj);
}
```

Three methods is a burden for "bring your own lookup". Mitigation: ship
`XFTY_AbstractSObjectProviderLookup` implementing all three in terms of a
`register(XFTY_LookupKeyIntf key, Type providerType)` call and a
`Map<String, XFTY_DummySobjectProviderIntf>` cache. `XFTY_DefaultSObjectProviderLookup`
becomes a thin subclass that just calls `register(...)` three times.

---

## Relationship class changes

Two new constructors on each relationship template:

```apex
new XFTY_DummyDefaultRelationshipRequired(SObject overrideTemplate)                       // existing — key derived later
new XFTY_DummyDefaultRelationshipRequired(XFTY_LookupKeyIntf key, SObject overrideTemplate) // explicit variant
```

(plus the existing `relatedField` variants).

### Should `Required` and `Optional` merge into one class first?

They differ only in which Master Template map they land in. Merging to a single
`XFTY_DummyDefaultRelationship` with an `isRequired` flag:

- collapses `requiredRelationshipBySObjectFieldMap` + `optionalRelationshipBySObjectFieldMap`
  into one `Map<SObjectField, XFTY_DummyDefaultRelationship>` that the factory
  filters by `.isRequired()`
- halves the constructor surface we're about to expand
- is a **breaking change**: `new XFTY_DummyDefaultRelationshipRequired(x)` →
  `XFTY_DummyDefaultRelationship.required(x)` (or similar)

The `put(...)` overloads keep working either way — `XFTY_DummyDefaultValueIntf`
and `XFTY_DummyDefaultRelationship` are distinct types, so overload resolution is
unambiguous even alongside the new `put(SObjectField, Object)`. Explicit
`putValue` / `putRelationship` names are a readability choice, not a necessity.

---

## Backwards compatibility

- `get(SObjectType)` stays and keeps working.
- `new XFTY_DummyDefaultRelationshipRequired(SObject)` stays and keeps working
  (derives the default type-only key).
- `XFTY_DummySObjectMasterTemplate` map shape changes only if we merge the
  relationship classes.
- Anyone who wrote their own `XFTY_DummySObjectProviderLookupIntf` implementation
  must add two methods (or extend the new abstract base). This is the one
  unavoidable break for existing external code.

---

## Open decisions (for review before implementation)

1. **Merge `Required` + `Optional` into one `XFTY_DummyDefaultRelationship`?**
   Recommend yes — do it as the first commit, before adding the key constructors.
2. **`putValue` / `putRelationship` explicit names, or keep `put(...)` overloads?**
   Recommend keep overloads (they resolve fine); add explicit aliases only if you
   want them for readability.
3. **Ship `XFTY_RecordTypeLookupKey`, or leave record-type keys as a documented
   example?** Recommend ship it — it's the compelling real use case and the
   `RecordTypeId` describe logic is fiddly enough to be worth centralising.
4. **`XFTY_AbstractSObjectProviderLookup` base class** to keep the interface
   cheap to implement? Recommend yes.
5. **Scope of test/doc updates** — this touches the factory, both relationship
   classes, the master template, the lookup, and ~4 test classes. Confirm it all
   lands on this branch (not merged) as one reviewable unit.

---

## Implementation plan

1. Merge relationship classes (decision 1) + update master template map + factory
   + tests + docs.
2. Add `XFTY_LookupKeyIntf`, `XFTY_LookupKey`, `XFTY_RecordTypeLookupKey` + tests.
3. Revise `XFTY_DummySObjectProviderLookupIntf` + add `XFTY_AbstractSObjectProviderLookup`
   + refactor `XFTY_DefaultSObjectProviderLookup` + tests.
4. Add explicit-key constructors to the relationship class; wire deferred
   resolution into `XFTY_DummySObjectFactory`; tests for a two-variant Provider.
5. Rewrite `XFTY_DefaultAccountDataProvider` to use a real Person/Business variant
   pair as the worked example; update `docs/providers.md` "Record Types".
6. Update `docs/relationships.md`, `docs/future-ideas.md`, `docs/known-issues.md`.
