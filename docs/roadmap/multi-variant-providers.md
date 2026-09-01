# Design: Multi-Variant Providers

Status: **implemented** on the `multi-variant-providers` branch, then revised
several times. The rest of this document is the original design record; where
things actually ended up:

- **The lookup is a plain map + a utility, not a registry.** A project's
  `XFTY_DummySObjectProviderLookupIntf` holds a complete, explicit
  `Map<XFTY_LookupKeyIntf, Type>` (or `..., provider instance>`) and delegates its
  three methods to `XFTY_ProviderLookups`. No `register(...)`, no mutation, no
  "last wins". `XFTY_DefaultSObjectProviderLookup` is that pattern with XFTY's
  three Providers - a copy-me starter and the framework's self-test lookup.
  (`@IsTest` classes can't be abstract/virtual, so an abstract base was never an
  option.)
- **All keys are flyweights and override `equals`/`hashCode` by `getHashKey()`**,
  so they work as `Map` keys directly. Obtain them with `.get(...)`.
  `XFTY_FlavouredLookupKey` is interned by type + record type + flavour; its
  `.matching(...)` predicates are behaviour, added once - typically in a
  `*LookupKeys` constants class both the Provider Lookup and the pinning
  relationships reference.
- **`keyFor` → `keysFor`** returns `Set<XFTY_LookupKeyIntf>` (a record can match
  several variants). `XFTY_ProviderLookups.resolve` picks the most specific via
  `XFTY_LookupKeyIntf.getSpecificity()` (0 / 10 / 20+); an equally-specific tie is
  an error.
- **`XFTY_FlavorLookupKey` → `XFTY_FlavouredLookupKey`**: `SObjectType` + optional
  record type + arbitrary `XFTY_SObjectPredicateIntf` conditions
  (`XFTY_FieldPredicate` ships the common ones).
- **`XFTY_RecordTypeLookupKeyIntf extends XFTY_LookupKeyIntf`** so any
  record-type-bearing key exposes its developer name / Id.
- **`XFTY_RecordTypeDataProvider`** rebuilt as a one-SOQL repository of all record
  types.
- **Deferred + memoised key resolution**, as proposed:
  `XFTY_DummyDefaultRelationshipIntf.resolveLookupKey(lookup)`.
- **`Required` + `Optional` merged** into `XFTY_DummyDefaultRelationship`;
  requiredness moved to the Master Template slot (`putRequired` / `putOptional`;
  a relationship passed to plain `put` is rejected).
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

The `put(...)` overloads keep working either way — `XFTY_ValueExpressionIntf`
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

## How the original questions were resolved

All of these were decided and shipped; kept here so the design record is complete.

1. **Merge `Required` + `Optional`?** Done - one `XFTY_DummyDefaultRelationship`,
   requiredness set by the Master Template slot (`putRequired` / `putOptional`).
2. **Explicit `put*` names vs. overloads?** `putRequired(...)` / `putOptional(...)`
   for relationships; `put(field, value)` for values (a non-strategy value is
   wrapped as an exact literal); the untyped `put(field, <relationship>)` throws.
3. **Ship `XFTY_RecordTypeLookupKey`?** Yes - shipped, plus `XFTY_FlavouredLookupKey`
   and `XFTY_FieldPredicate`. If it's reusable, it ships.
4. **An abstract base lookup class?** No. `@IsTest` classes can't be abstract or
   virtual, and the project uses composition anyway: `XFTY_ProviderLookups` is a
   stateless utility, and a project's lookup is a small class holding a complete
   `Map` that delegates its three methods to it.
5. **Scope / reviewability.** Landed on the `4.0-beta` integration branch
   (formerly `sfdx-package-and-tests`). Not on `master`.

Key resolution is memoised on the relationship (`resolveLookupKey`), derived from
the override template's type + record type unless an explicit key was given.
