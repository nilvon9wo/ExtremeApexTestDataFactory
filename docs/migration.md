# Migrating to the next XFTY

This release batches every breaking change together, on purpose - so you migrate
once rather than chasing a moving target. Nothing here is on `master` yet.

Work top to bottom; each item says exactly what to change.

---

## 1. Source format

XFTY is now a Salesforce DX **source-format** project. Classes live under
`force-app/main/default/classes/<area>/` (`core`, `values`, `relationships`,
`lookup`, `providers`, `tests`). If you vendored XFTY's `src/classes`, re-vendor
from `force-app`. Deploy is unchanged (`sf project deploy start`).

## 2. `XFTY_InsertMocker` is gone

It was a byte-for-byte duplicate of `XFTY_IdMocker`. Replace any reference with
`XFTY_IdMocker` (same API).

## 3. Relationship strategies merged

`XFTY_DummyDefaultRelationshipRequired` and `XFTY_DummyDefaultRelationshipOptional`
are now one class, `XFTY_DummyDefaultRelationship`. **Requiredness is set by the
Master Template slot**, not the type:

```apex
// before
.put(Contact.AccountId, new XFTY_DummyDefaultRelationshipRequired(new Account()))
// after
.putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
.putOptional(Contact.ReportsToId, new XFTY_DummyDefaultRelationship(new Contact()))
```

`put(field, <relationship>)` (untyped) now **throws** - it can't tell whether you
meant required or optional. Use `putRequired` / `putOptional`.

## 4. Provider Lookups: keys instead of a registry

`XFTY_DummySObjectProviderLookupIntf` gained two methods:

```apex
XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey);
Set<XFTY_LookupKeyIntf> keysFor(SObject sObj);
```

The recommended lookup is now a small class holding a **complete, explicit `Map`**
of `XFTY_LookupKeyIntf` → Provider, delegating mechanics to `XFTY_ProviderLookups`
(no stateful `register(...)`). Copy `XFTY_DefaultSObjectProviderLookup` as the
template. Full guide: [Providers → Provider Lookups](providers.md#provider-lookups).

```apex
@IsTest
public class MyProjectLookup implements XFTY_DummySObjectProviderLookupIntf {
    private static final Map<XFTY_LookupKeyIntf, Type> PROVIDERS = new Map<XFTY_LookupKeyIntf, Type>{
        XFTY_LookupKey.get(Account.SObjectType) => MyAccountProvider.class,
        XFTY_LookupKey.get(Contact.SObjectType) => MyContactProvider.class
    };
    private final Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf> cache =
            new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>();

    public XFTY_DummySobjectProviderIntf get(SObjectType t)          { return XFTY_ProviderLookups.get(PROVIDERS, cache, XFTY_LookupKey.get(t)); }
    public XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf key) { return XFTY_ProviderLookups.get(PROVIDERS, cache, key); }
    public Set<XFTY_LookupKeyIntf> keysFor(SObject sObj)             { return XFTY_ProviderLookups.keysFor(PROVIDERS.keySet(), sObj); }
}
```

## 5. `createBundle` takes a context (every Provider needs this)

`XFTY_DummySobjectProviderIntf.createBundle` changed:

```apex
// before
XFTY_DummySObjectBundle createBundle(
        XFTY_DummySObjectProviderLookupIntf providerLookup,
        List<SObject> templateSObjectList,
        XFTY_InsertModeEnum insertMode,
        XFTY_InsertInclusivityEnum inclusivity);

// after
XFTY_DummySObjectBundle createBundle(
        XFTY_GenerationContext context,
        List<SObject> templateSObjectList);
```

In practice every Provider's body is a one-line forward, so the change is:

```apex
// before
return XFTY_DummySObjectFactory.createBundle(providerLookup, MASTER_TEMPLATE, templateSObjectList, insertMode, inclusivity);
// after
return XFTY_DummySObjectFactory.createBundle(context, MASTER_TEMPLATE, templateSObjectList);
```

If you call `XFTY_DummySObjectFactory.createBundle` directly, wrap the three
scalars: `new XFTY_GenerationContext(providerLookup, insertMode, inclusivity)`.
`XFTY_DummySObjectFactory.cloneAndCompleteNonRelationshipValues` is renamed
`cloneAndCompletePlainValues`.

## 6. `XFTY_DefaultUserDataProvider.profileIdFor` / `roleIdFor` throw

They used to return `null` for an unknown Profile / UserRole; now they throw
`XFTY_DefaultUserDataProvider.UnknownReferenceException` at the call site. If a
role is genuinely optional in your test, query for it yourself instead of relying
on `null`.

## 7. Removed defensive surface

`IndeterminateSObjectTypeException` and its guards were removed after being proven
unreachable. If you caught it, you can drop the catch.

---

## New things you may want

Not required, but available:

| Feature | Where |
|---------|-------|
| `put(field, 'literal')` - implicit `XFTY_DummyDefaultValueExact` | [Customization → Implicit Exact Values](customization.md#implicit-exact-values) |
| `withVariant(key)` / `new XFTY_DummySObjectProvider(key, lookup)` / `new XFTY_DummySObjectProvider(template, lookup)` | [Providers → Record Types and Variants](providers.md#record-types-and-variants), [Getting Started → Shorthand Constructors](getting-started.md#shorthand-constructors) |
| Record-type / flavour Provider variants (`XFTY_RecordTypeLookupKey`, `XFTY_FlavouredLookupKey`, `XFTY_FieldPredicate`) | [Providers → Record Types and Variants](providers.md#record-types-and-variants) |
| Context-aware values (`XFTY_CopyFromSibling`, `XFTY_CopyFromAncestor`, `XFTY_ContextAwareValueIntf`) | [Customization → Context-Aware Values](customization.md#context-aware-values) |
| Per-call relationship control (`includeOptional(field)`, `includeOptional(path)`, `excludeRelationship`) | [Relationships → One-Off Exceptions](relationships.md#one-off-exceptions-includeoptional--excluderelationship) |
| Shared ancestors (`XFTY_SharedAncestor` - many children under one generated parent) | [Relationships → Shared Ancestors](relationships.md#shared-ancestors) |
| `.depthBatched()` - opt-in, one `insert` per dependency depth instead of one per Provider | [Testing Modes → Depth-Batched Persistence](testing-modes.md#depth-batched-persistence-depthbatched) |
| `DEFERRED` insert mode + `XFTY_DeferredInserter.flush()` - generate over many calls, insert once | [Testing Modes → DEFERRED](testing-modes.md#deferred) |
| `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` test suites | [Packaging → Test suites](packaging.md#test-suites) |
