# Migrating from XFTY 3.5 to 4.0

4.0 batches every breaking change together, on purpose — so you migrate once
rather than chasing a moving target. "3.5" means the `v3.5.0` tag: the state of
`master` before 4.0 development began. Full change list: [../../CHANGELOG.md](../../CHANGELOG.md).

Work top to bottom; each item says exactly what to change.

---

## Who this affects

| If you… | Migration effort |
|---------|------------------|
| use the **bundled** `Account` / `Contact` / `User` Providers and nothing else | **Minimal** — re-vendor from `force-app/`, pass a lookup to the constructor (§1, §4), rename any value-expression types you reference by name (§8). Most test bodies are untouched. |
| wrote your **own Providers** | **Moderate** — update `createBundle`'s signature (§5), move to a keyed lookup (§4), split `putRequired` / `putOptional` (§3). Mechanical; the guide gives the exact before/after. |
| wrote **custom value strategies** or a **project lookup** | **Moderate** — the type renames in §8, plus the lookup interface's two new methods (§4). |
| `catch` framework exceptions or call internal helpers directly | **Check §5, §6, §7** — a couple of return-`null`s became throws, and one public wrapper moved. |

Nothing here changes what a generated record *is* — only the API used to ask for it.

---

## 1. Source format

XFTY is now a Salesforce DX **source-format** project. Classes live under
`force-app/main/default/classes/<area>/` (`core`, `engine`, `persistence`,
`values`, `relationships`, `lookup`, `predicates`, `providers`), each class's
test beside it.
If you vendored XFTY's `src/classes`, re-vendor from `force-app`. Deploy is
unchanged (`sf project deploy start`).

`test-support/` is a **second, non-default package directory**. It holds
examples, load tests, and org-only tests that a published package must not force
on a consumer (Person Accounts, a demo custom object). You do not deploy it to
production.

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

`put(field, <relationship>)` (untyped) now **throws** — it can't tell whether you
meant required or optional. Use `putRequired` / `putOptional`.

## 4. Provider Lookups: keys instead of a registry

Every `XFTY_DummySObjectProvider` now takes a **Provider Lookup** as its second
constructor argument — there is no global registry any more:

```apex
// before
new XFTY_DummySObjectProvider(Contact.SObjectType)
// after
new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
```

`XFTY_DummySObjectProviderLookupIntf` gained two methods:

```apex
XFTY_DummySobjectProviderIntf get(XFTY_LookupKeyIntf lookupKey);
Set<XFTY_LookupKeyIntf> keysFor(SObject sObj);
```

The recommended lookup is a small class holding a **complete, explicit `Map`**
of `XFTY_LookupKeyIntf` → Provider, delegating mechanics to `XFTY_ProviderLookups`
(no stateful `register(...)`). Copy `XFTY_DefaultSObjectProviderLookup` as the
template, or build one inline with `XFTY_ProviderLookups.of(map)`. Full guide:
[extend/provider-lookups](../extend/provider-lookups.md).

```apex
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

`XFTY_DefaultSObjectProviderLookup.get(...)` also **throws** for an unknown
`SObjectType` now (it used to swallow the error and return `null`, surfacing
later as an opaque NPE).

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

The engine internals were split into per-phase classes. The public wrapper
`XFTY_DummySObjectFactory.cloneAndCompleteNonRelationshipValues` (later briefly
`cloneAndCompletePlainValues`) is **gone** — the plain-value logic now lives in
`XFTY_PlainValueFiller.cloneAndCompletePlainValues(masterTemplate, testTemplates)`.
Only code that called that wrapper directly is affected.

## 6. `XFTY_DefaultUserDataProvider.profileIdFor` / `roleIdFor` throw

They used to return `null` for an unknown Profile / UserRole; now they throw
`XFTY_DefaultUserDataProvider.UnknownReferenceException` at the call site. If a
role is genuinely optional in your test, query for it yourself instead of relying
on `null`.

## 7. Removed defensive surface

`IndeterminateSObjectTypeException` and its guards were removed after being proven
unreachable. If you caught it, you can drop the catch.

Provider-level `put(...)` and `removeFromMasterTemplate(...)` were silent no-ops
in 3.5 and now actually take effect. If a test happened to call one expecting
nothing to happen, it will now change the generated data.

## 8. Value strategies renamed to value expressions

The value-producing types dropped their `DummyDefault` prefix and took an
`Expression` suffix. Mechanical rename — the behaviour is unchanged:

| before | after |
|---|---|
| `XFTY_DummyDefaultValueIntf` | `XFTY_ValueExpressionIntf` |
| `XFTY_ContextAwareValueIntf` | `XFTY_ContextAwareExpressionIntf` |
| `XFTY_DeferredValueIntf` | `XFTY_DeferredExpressionIntf` |
| `XFTY_DummyDefaultValueExact` | `XFTY_LiteralExpression` |
| `XFTY_DummyDefaultValueIncrementingString` | `XFTY_IncrementingStringExpression` |
| `XFTY_DummyDefaultValueUniqueString` | `XFTY_UniqueStringExpression` |
| `XFTY_DummyDefaultValueUniqueStringLength` | `XFTY_UniqueStringOfLengthExpression` |
| `XFTY_DummyDefaultValueUniqueEmail` | `XFTY_UniqueEmailExpression` |
| `XFTY_DummyDefaultIncrementingDecimal` | `XFTY_IncrementingDecimalExpression` |
| `XFTY_CopyFromSibling` | `XFTY_CopyFromSiblingExpression` |
| `XFTY_CopyFromAncestor` | `XFTY_CopyFromAncestorExpression` |
| `XFTY_CopyFromDescendant` | `XFTY_CopyFromDescendantExpression` |

`XFTY_DummyDefaultRelationship` is a relationship, not a value expression, and is
**unchanged**. The doc pages moved: `use/value-strategies.md` →
`use/value-expressions.md`, `extend/custom-value-strategies.md` →
`extend/custom-value-expressions.md`.

---

## New in 4.0 — not required, but available

| Feature | Where |
|---------|-------|
| `put(field, 'literal')` — implicit `XFTY_LiteralExpression` | [use/value-expressions](../use/value-expressions.md#implicit-exact-values) |
| `withVariant(key)` / lookup-key constructor / template constructor | [use/provider-variants](../use/provider-variants.md), [use/generating-records](../use/generating-records.md#shorthand-constructors) |
| Record-type / flavour Provider variants (`XFTY_RecordTypeLookupKey`, `XFTY_FlavouredLookupKey`, `XFTY_FieldPredicate`) | [extend/provider-variants](../extend/provider-variants.md) |
| Context-aware values (`XFTY_CopyFromSiblingExpression`, `XFTY_CopyFromAncestorExpression`, `XFTY_ContextAwareExpressionIntf`) | [use/context-aware-values](../use/context-aware-values.md) |
| `context.siblingValue(field)` for custom context-aware expressions — guarded sibling read, throws instead of returning a misleading `null` | [use/context-aware-values](../use/context-aware-values.md) |
| Descendant (up-flowing) value reads — `XFTY_CopyFromDescendantExpression`, a parent field copied up from a generated child (`DEFERRED` / `.depthBatched()` only) | [use/context-aware-values](../use/context-aware-values.md#reading-up-from-a-child) |
| Per-call relationship control (`includeOptional(field)`, `includeOptional(path)`, `excludeRelationship`) | [use/per-call-relationships](../use/per-call-relationships.md) |
| Path-scoped value overrides — `put(List<SObjectField>, …)` sets a field on a generated ancestor for one call | [use/value-expressions](../use/value-expressions.md#setting-a-value-on-a-generated-ancestor) |
| Downward generation — `with(...)` / `withChildren(...)` / `XFTY_SObjectChildProvider` generate the records *below* a primary, nested | [use/child-records](../use/child-records.md) |
| Shared ancestors (`XFTY_SharedAncestor` — many children under one generated parent, flat or deep; `XFTY_SharedAncestorDefaultsIntf` for packaged defaults) | [use/shared-ancestors](../use/shared-ancestors.md) |
| `.depthBatched()` — opt-in, one `insert` per dependency depth instead of one per Provider | [use/deferred-insert](../use/deferred-insert.md) |
| `DEFERRED` insert mode + `XFTY_DeferredInserter.flush()` — generate over many calls, insert once | [use/deferred-insert](../use/deferred-insert.md) |
| Governor-limit warnings — `XFTY_GovernorBudget` warns in the debug log when generation crosses half of a limit; tune with the `XFTY_Settings__c` custom setting | [reference/volume-and-limits](volume-and-limits.md) |
| `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` / `XFTY_Examples` / `XFTY_OrgOnly` / `XFTY_PersonAccount` test suites | [contribute/test-suites](../contribute/test-suites.md) |
