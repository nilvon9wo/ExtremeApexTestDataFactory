# Shared Ancestors

By default every generated child gets its **own** generated parent. When several
children should sit under **one** parent — 50 Contacts at the same Account, a
whole hierarchy converging on one root — use `XFTY_SharedAncestor`.

> Status: the **on-demand** path shown here is shipped. Declared ancestors, deep
> shared chains, and fully DML-batched resolution are proposed — see
> [roadmap/shared-ancestors.md](../roadmap/shared-ancestors.md).

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

## Limits of the current version

- Each shared ancestor is generated with its own `createBundle` call, so
  resolving *N* shared ancestors in `NOW` mode still costs *N* inserts (better
  than one per child, not yet one total).
- **Use one insert mode per shared ancestor within a test.** If it is first
  resolved in a `MOCK` call and then referenced from a `NOW` call, XFTY throws a
  clear "consistent insert mode" error rather than drift a mock Id into real DML.
  To share a real record across a `NOW` test, insert it yourself and register it
  with `XFTY_SharedAncestor.put(name, record)`.
- After `XFTY_SharedAncestor.put(name, record)`, `bundle.getBundle(field)`
  returns null (only `getList(field)` is filled) — a bug being fixed
  ([known-issues](../reference/known-issues.md)). When the ancestor is
  *generated*, both work.

Deep shared chains, up-front `require(...)` declaration, and DML-batched
resolution are [on the roadmap](../roadmap/shared-ancestors.md).

---

## In a shipped Master Template

Putting an `XFTY_SharedAncestor` in a Provider you distribute (rather than on a
`XFTY_DummySObjectProvider` instance in one test) is an *extend* concern — see
[extend/shared-ancestors-in-templates.md](../extend/shared-ancestors-in-templates.md).

▶ Runnable: `XFTY_Ex_SharedAncestorsTest` _(pending — Pass B)_

See also: [relationships](relationships.md) · [bundles](bundles.md) ·
[insert-modes](insert-modes.md)
