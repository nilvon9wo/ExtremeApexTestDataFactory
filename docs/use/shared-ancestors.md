# Shared Ancestors

By default every generated child gets its **own** generated parent. When several
children should sit under **one** parent — 50 Contacts at the same Account, a
whole hierarchy converging on one root — use `XFTY_SharedAncestor`.

---

## One API — resolution is automatic

There is nothing to declare or opt into. A shared ancestor is registered once —
by the [lookup that ships the Providers](#packaged-defaults) for the common case,
or by the test — and referenced anywhere; XFTY works out how to resolve it.

Before a Provider generates anything, every shared ancestor configured in the
current test method is resolved in one place, each honouring the call's insert
mode. XFTY inspects each one's Provider:

| The shared ancestor's Provider… | How it resolves |
|---|---|
| **has no relationships of its own** ("flat" — a plain `Account`, a `Pricebook`) | one record, one `insert` (in `NOW`) |
| **pulls in ancestors of its own** ("deep" — a record-type chain, a heavy graph) | its whole sub-graph is built once and inserted **one dependency layer at a time** — the fewest `insert` statements; a chain converging on a singleton root collapses to one shared sub-graph |

Either way: **one record, one Id, everywhere** — and it is generated at most once
per test method.

---

## The simplest case

```apex
// register once - centrally for shipped Providers (see "Packaged defaults"), or in the test
XFTY_SharedAncestor.put('acme-hq', new Account(Name = 'ACME HQ'));

// reference it from any Master Template, any field, required or optional
new XFTY_DummySObjectMasterTemplate(Contact.Id)
    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('acme-hq'));
```

```apex
List<Contact> contacts = (List<Contact>) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setQuantityPerTemplate(50)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .supplyList();
// -> 50 Contacts, ONE generated Account, ONE Account insert
```

- **One record, one Id.** Every child that references `'acme-hq'` gets the same
  `Account` instance and the same `AccountId`.
- **Generated once per test method.** Every reference — in the same or a later
  `supply*()` call — reuses it. State is static, so it resets between test
  methods automatically. Each test configures its own shared ancestors
  (Salesforce never shares data between tests — see
  [../reference/salesforce-considerations.md](../reference/salesforce-considerations.md)).
- **Persistence follows the call.** `NOW` inserts it, `MOCK` gives it a mock Id,
  `NEVER` leaves it Id-less. A `.depthBatched()` / `DEFERRED` call resolves its
  shared ancestors **up front** (so their Ids are ready when the deferred graph
  flushes) rather than deferring them.

---

## A deep shared ancestor

Nothing extra to do — configure the rungs and reference the leaf:

```apex
// once, centrally
XFTY_SharedAncestor.put('root', new MyHierarchyObj__c())
    .fromVariant(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));
XFTY_SharedAncestor.put('level1', new MyHierarchyObj__c())
    .fromVariant(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Level1'));
// level1's Provider does putRequired(MyHierarchyObj__c.Parent__c, XFTY_SharedAncestor.get('root'))
```

```apex
MyHierarchyObj__c leaf = (MyHierarchyObj__c) new XFTY_DummySObjectProvider(
        XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Level9'), lookup)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
// Level9 -> ... -> Level1 -> the one shared Root. A second supply() for a
// different leaf reuses that same Level1 and Root.
```

- **A shared ancestor referenced by another shared ancestor's Provider is pulled
  in automatically**, resolved before the one that needs it — you do not list
  every rung.
- **Depth-batched, mode-aware.** Each deep shared ancestor's sub-graph is
  inserted one dependency layer at a time (`NOW`), mock-Id'd (`MOCK`), or left in
  memory (`NEVER`).
- **Deep chains past 10 levels log a `WARN`.** A cycle (`a` needs `b`, `b` needs
  `a`) **throws** — break it by pre-registering one side with
  `XFTY_SharedAncestor.put(name, record)`.

---

## Registering

`put(name, ...)` registers; `get(name)` only retrieves (the token to hand to
`putRequired` / `putOptional`, and the handle for `resolveNow` / `getId`).

| Call | Effect |
|------|--------|
| `XFTY_SharedAncestor.get(name)` | the interned shared ancestor for `name` — retrieval only |
| `XFTY_SharedAncestor.put(name, SObject record)` | register `record`. **Id present** → a fixed value; **no Id** → an override template. Logs which; use the explicit forms to be sure |
| `XFTY_SharedAncestor.putAsTemplate(name, SObject template)` | always an override template (generated in the pre-phase; also sets the type) |
| `XFTY_SharedAncestor.putAsValue(name, SObject record)` | always used as-is |
| `XFTY_SharedAncestor.put(name, XFTY_LookupKeyIntf key)` | register just the Provider variant that generates it ([provider-variants](provider-variants.md)) |
| `.fromVariant(XFTY_LookupKeyIntf key)` | chained off `putAsTemplate` / `put(name, record)` — pin the variant *and* keep the template |
| `XFTY_SharedAncestor.put(name, XFTY_DummySObjectProvider provider)` | build it from a fully-configured Provider — see below. Not combined with the template / key forms |
| `.copyingRelatedField(SObjectField f)` | copy `f` from the shared record into the child's field instead of its Id |
| `XFTY_SharedAncestor.putIfAbsent(name, template)` | `putAsTemplate`, only if `name` is not registered yet this test — for a shared setup helper that may run more than once, or that registers more ancestors than one test uses |
| `XFTY_SharedAncestor.putIfAbsent(name, lookupKey)` | as above, pinning the Provider variant instead of a template |

Re-registering a shared ancestor after it has resolved throws.

### `put(name, provider)` — the whole generation API for one shared record

When a template / key is not enough — you need value strategies on the shared
record, or want to shape *its* own ancestors — hand `put(name, provider)` a
fully-configured `XFTY_DummySObjectProvider`:

```apex
XFTY_SharedAncestor.put('hq', 
    new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
        .setOverrideTemplate(new Account(Name = 'HQ Ltd'))
        .withVariant(enterpriseKey)
        .put(Account.Rating, new XFTY_DummyDefaultValueExact('Hot'))
        .put(Account.Site, 'Berlin')
        .putRequired(Account.ParentId, new XFTY_DummyDefaultRelationship(new Account(Name = 'Global HQ')))
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .includeOptional(Account.OwnerId)
        .put(new List<SObjectField>{ Account.ParentId, Account.Site }, 'Global')
);
```

Anything that shapes a single record applies. The Provider carries its own
override template, variant, **and lookup** (so the shared ancestor's Provider can
come from your project's full lookup even when the test itself uses a minimal
one). Persistence still follows the call that references it (or
`resolveNow(lookup, mode)`).

The knobs that describe **more than one record** are rejected with a clear error,
because a shared ancestor is exactly one: `setQuantityPerTemplate(n > 1)`, a
multi-element `setOverrideTemplateList([...])`, `setInsertMode(...)` (persistence
follows the referencing call), `.depthBatched()` (the resolver already
depth-batches), and child collections (`with(...)` / `withChildren(...)`).

`put(name, provider)` and the template / key forms cannot both be set — the
Provider already says everything they would.

**The shared record's own field values go on the template / provider** — it is
one record for every child, so there is no per-call place to set them. A
`put(new List<SObjectField>{ theSharedRelationshipField, deeperField }, value)`
that would *set a value on* a shared ancestor
([per-call ancestor values](per-call-relationships.md)) **throws**. Wiring a
shared ancestor **in** as a relationship value —
`putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId }, XFTY_SharedAncestor.get('mr-smith'))` —
is fine.

---

## Packaged defaults

A Provider you ship should work without every consuming test knowing its shared
ancestors' names. Put the defaults on the **lookup** — the package boundary a
consumer already depends on.

The quick form: pass them alongside the Provider map.

```apex
XFTY_ProviderLookups.of(
    new Map<XFTY_LookupKeyIntf, XFTY_DummySobjectProviderIntf>{
        XFTY_LookupKey.get(Account.SObjectType) => new MyAccountProvider(),
        XFTY_LookupKey.get(Contact.SObjectType) => new MyContactProvider()   // references get('acme-hq')
    },
    new Map<String, SObject>{ 'acme-hq' => new Account(Name = 'ACME HQ') }
);
```

A hand-written lookup implements the companion interface
**`XFTY_SharedAncestorDefaultsIntf`** — one method:

```apex
public class MyProjectLookup implements XFTY_DummySObjectProviderLookupIntf, XFTY_SharedAncestorDefaultsIntf {
    // ... the usual get / keysFor ...
    public void registerSharedAncestorDefaults() {
        XFTY_SharedAncestor.putIfAbsent('acme-hq', new Account(Name = 'ACME HQ'));
        XFTY_SharedAncestor.putIfAbsent('primary-price-book', new Pricebook2(Name = 'Standard'));
    }
}
```

XFTY calls it before each `supply*()` resolves shared ancestors. Because it uses
**`putIfAbsent`**, a test that wants a different shared record just registers it
first — the default is skipped. A lookup with no shared ancestors does not
implement the interface.

▶ Runnable: `XFTY_SharedAncestorHierarchyTest.aLookupSuppliesTheSharedAncestorSoNoTestRegistrationIsNeeded`

---

## Supplying your own record, and reading the Id

```apex
Account root = /* the test inserts its own singleton root */;
XFTY_SharedAncestor.put('root', root);   // from here, get('root') resolves to this

Id hqId = XFTY_SharedAncestor.getId('acme-hq');  // after it has resolved
```

`getId(name)` throws if the ancestor has not been resolved yet this test method.
To read it **before** any `supply*()` call, resolve it explicitly:

```apex
XFTY_SharedAncestor.get('root').resolveNow(lookup, XFTY_InsertModeEnum.NOW);
Id rootId = XFTY_SharedAncestor.getId('root');
```

`resolveNow(lookup, mode)` also fixes the shared record's own insert mode
independently of the call that first references it — resolve it `MOCK` up front
and later `NOW` calls reuse that mock record.

---

## Gotchas

- **One insert mode per shared ancestor within a test.** If it is first resolved
  `MOCK` and then referenced from a `NOW` call, XFTY throws a clear "consistent
  insert mode" error rather than drift a mock Id into real DML. Share a real
  record across a `NOW` test by inserting it yourself and registering it with
  `XFTY_SharedAncestor.put(name, record)`, or by resolving it `NOW` up front with
  `resolveNow(lookup, XFTY_InsertModeEnum.NOW)`.
- **Configuring one you never reference still resolves it.** Each shared ancestor
  configured this test method is resolved before the first `supply*()`. Configure
  the ones this test uses; use `putIfAbsent(...)` if a shared helper configures a
  superset.
- **A cycle throws.** Two shared ancestors that need each other, or one whose
  Provider references it back — break it with `put(name, record)`.

### Still open

- Resolution is one depth-batched pass **per shared ancestor sub-graph**, not one
  pass across every shared ancestor at once.
- Only the **relationships reachable from the call** could be resolved instead of
  every registered shared ancestor — a walk of the Master Template graph
  (planned; `putIfAbsent` is the interim answer).
- Load-test data for the depth-batch cost, documented limits, and a
  disable-this-record / disable-the-feature off-switch (design-doc decision 3)
  are not done.
- The full deep-record-type-hierarchy acceptance test needs `test-support`
  metadata (a custom SObject + ≥10 record types + a singleton trigger) that is
  not in the repo — the mechanics are covered by `XFTY_SharedAncestorHierarchyTest`
  using `Account.ParentId`.

---

## In a shipped Master Template

Putting an `XFTY_SharedAncestor` in a Provider you distribute (rather than on a
`XFTY_DummySObjectProvider` instance in one test) is an *extend* concern — see
[extend/shared-ancestors-in-templates.md](../extend/shared-ancestors-in-templates.md).

▶ Runnable: `XFTY_SharedAncestorTest` (the basics) ·
`XFTY_SharedAncestorHierarchyTest` (deep chains, `suppliedBy`, cross-SObject, a
full three-level all-shared spine end to end) · `XFTY_SharedAncestorLoadTest`
(500 children, one parent insert)

See also: [relationships](relationships.md) · [bundles](bundles.md) ·
[insert-modes](insert-modes.md)
