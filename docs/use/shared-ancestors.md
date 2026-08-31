# Shared Ancestors

By default every generated child gets its **own** generated parent. When several
children should sit under **one** parent — 50 Contacts at the same Account, a
whole hierarchy converging on one root — use `XFTY_SharedAncestor`.

---

## Two kinds

Both are implemented.

| | **On-demand** | **Declared** |
|---|---|---|
| How the test asks for it | `get(name).of(...)` and reference it — **nothing to register** | `XFTY_SharedAncestor.declared(name).of(...)` centrally, then `require(name)` at the top of the test |
| When it resolves | lazily, the first time generation references it | up front, in a batched pre-phase (S0–S2), before this test's first `supply*()` |
| What it may be | **lightweight — no ancestors of its own** (a self-referential one throws rather than recurse; a plain non-self parent works but adds an `insert`) | **may be deep**, may have its own (declared or ordinary) ancestors, may be heavy |
| Reaching one the test did not ask for | just builds it | **throws** — names the ancestor, tells you to `require(...)` it |
| Cost in `NOW` | one `insert` per shared ancestor | one depth-batched `insert` pass per declared ancestor's subgraph |
| `.depthBatched()` / `DEFERRED` main call | **not supported** (throws — reference it from a `NOW`/`MOCK`/`NEVER` call) | supported (it is pre-resolved) |

Use **on-demand** for the common light case — a shared `Account`, a shared
`Pricebook`. Use **declared** when the shared record is itself a hierarchy (a
deep record-type chain converging on a singleton root), or heavy enough that you
want it built once, batched, up front.

The rest of this page is **on-demand**. Declared has its own section at the end.

---

## The simplest case

```apex
// configure once, somewhere central (a *LookupKeys-style constants class is ideal)
XFTY_SharedAncestor.get('acme-hq').of(new Account(Name = 'ACME HQ'));

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
- **Generated once per test method.** The first reference generates (and, in
  `NOW` mode, inserts) it; every later reference — in the same or a later
  `supply*()` call — reuses it. State is static, so it resets between test
  methods automatically. Each test configures its own shared ancestors
  (Salesforce never shares data between tests — see
  [../reference/salesforce-considerations.md](../reference/salesforce-considerations.md)).
- **Persistence follows the call.** `NOW` inserts it, `MOCK` gives it a mock Id,
  `NEVER` leaves it Id-less — same as any relationship.

---

## Configuring

| Call | Effect |
|------|--------|
| `.of(SObject template)` | The override template for the shared record (also sets its type). Required before generation. |
| `.withKey(XFTY_LookupKeyIntf key)` | Pin which Provider variant generates it (see [provider-variants](provider-variants.md)). |
| `.copyingRelatedField(SObjectField f)` | Copy `f` from the shared record into the child's field instead of its Id. |

Reconfiguring a shared ancestor after it has resolved throws.

**The shared record's own field values go on `.of(...)`** — it is one record for
every child, so there is no per-call place to set them. A
`put(new List<SObjectField>{ theSharedRelationshipField, deeperField }, value)`
that would *set a value on* a shared ancestor
([per-call ancestor values](per-call-relationships.md)) **throws**. Wiring a shared ancestor **in** as a relationship value —
`putRequired(new List<SObjectField>{ Contact.AccountId, Account.OwnerId }, XFTY_SharedAncestor.get('mr-smith'))` —
is fine (on-demand, no `require()` needed).

---

## Supplying your own record, and reading the Id

```apex
Account root = /* the test inserts its own singleton root */;
XFTY_SharedAncestor.put('root', root);   // from here, get('root') resolves to this

Id hqId = XFTY_SharedAncestor.getId('acme-hq');  // after it has resolved
```

`getId(name)` throws if the ancestor has not been resolved yet this test method
(reference it from a relationship in a `supply*()` call first, or `put(...)` a
record).

---

## Limits of on-demand

- Each on-demand shared ancestor is generated with its own `createBundle` call,
  so resolving *N* on-demand shared ancestors in `NOW` mode costs *N* inserts
  (better than one per child, not one total — use **declared** for that).
- **One insert mode per on-demand shared ancestor within a test.** If it is first
  resolved in a `MOCK` call and then referenced from a `NOW` call, XFTY throws a
  clear "consistent insert mode" error rather than drift a mock Id into real DML.
  To share a real record across a `NOW` test, insert it yourself and register it
  with `XFTY_SharedAncestor.put(name, record)`, or use a **declared** ancestor
  with `context(NOW)`.
- **Not supported with `.depthBatched()` / `DEFERRED`** on the referencing call —
  it throws. Reference an on-demand shared ancestor from a `NOW` / `MOCK` /
  `NEVER` call, or make it **declared**.

---

## Declared shared ancestors

For a shared record that is itself a hierarchy, or heavy. It resolves once, up
front, in a batched pass — and a test must **opt in** to it.

```apex
// once, centrally (a *LookupKeys-style constants class is ideal)
XFTY_SharedAncestor.declared('root')
    .of(new MyHierarchyObj__c())
    .withKey(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));

// reference it from a Master Template exactly like an on-demand one
new XFTY_DummySObjectMasterTemplate(MyHierarchyObj__c.Id)
    .putRequired(MyHierarchyObj__c.Parent__c, XFTY_SharedAncestor.get('root'));
```

```apex
// at the top of the test - opt in
XFTY_SharedAncestor.require('root');
// or, when you will read getId(...) before any supply*() call:
XFTY_SharedAncestor.context(XFTY_InsertModeEnum.NOW).require('root');

MyHierarchyObj__c leaf = (MyHierarchyObj__c) new XFTY_DummySObjectProvider(
        XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Level9'), lookup)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
// Level9 -> ... -> Level1 -> the one shared Root. A second supply() for a
// different leaf reuses that same Root.
```

| Call | Effect |
|------|--------|
| `XFTY_SharedAncestor.declared(name)` | mark `name` declared; returns it for `.of(...)` / `.withKey(...)` |
| `.require(name)` / `.require(a, b[, c[, d]])` / `.require(List<String>)` | this test needs these declared ancestors — call at the top |
| `.context(XFTY_InsertModeEnum).require(...)` | fix the insert mode for the declared pre-phase (needed only if you read `getId(...)` before any `supply*()`) |
| `.resolveDeclared(lookup)` | run the pre-phase now (needs the mode set via `context(...)`) |

- **Requiring one pulls in its nested declared ancestors.** If `level1`'s
  Provider requires `root` (also declared), `require('level1')` resolves `root`
  too — you do not list every rung.
- **Reaching a declared ancestor you did not require throws** — `get(name)`,
  `getId(name)`, or a relationship that resolves to it during generation. It
  names the ancestor and tells you to add the `require(...)`. No silent build.
- **Depth-batched, mode-aware.** Each declared ancestor's subgraph is inserted
  one dependency layer at a time (`NOW`), mock-Id'd (`MOCK`), or left alone
  (`NEVER`). Deep declared chains past 10 levels log a `WARN`; a cycle
  (`a` needs `b`, `b` needs `a`) throws — break it by pre-registering one side
  with `XFTY_SharedAncestor.put(name, record)`.
- Works with `.depthBatched()` / `DEFERRED` on the referencing call (it is
  already resolved by then).

### Still open

- Resolution is one depth-batched pass **per declared ancestor**, not one pass
  across the whole declared set.
- Load-test data for the depth-batch cost, documented limits, and a
  disable-this-record / disable-the-feature off-switch (design-doc decision 3)
  are not done.
- The full deep-record-type-hierarchy acceptance test needs `test-support`
  metadata (a custom SObject + ≥10 record types + a singleton trigger) that is
  not in the repo — the mechanics are covered by `XFTY_DeclaredAncestorTest`
  using `Account.ParentId`.

---

## In a shipped Master Template

Putting an `XFTY_SharedAncestor` in a Provider you distribute (rather than on a
`XFTY_DummySObjectProvider` instance in one test) is an *extend* concern — see
[extend/shared-ancestors-in-templates.md](../extend/shared-ancestors-in-templates.md).

▶ Runnable: `XFTY_SharedAncestorTest` (on-demand) · `XFTY_DeclaredAncestorTest` (declared)

See also: [relationships](relationships.md) · [bundles](bundles.md) ·
[insert-modes](insert-modes.md)
