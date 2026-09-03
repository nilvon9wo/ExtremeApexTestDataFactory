# Enriching for the Code Under Test — `inject` / `injectAll`

A generated graph puts related records on the **bundle** — you read them with
`bundle.getBundle(...)` chains or `bundle.getValue(path)`. The **code under test**
can't: it does `contact.Account.Name` or `account.Contacts` straight off the
SObject, and an in-memory SObject carries neither until something writes them.

`inject` re-expresses the parts of the graph the bundle already holds in the
shape `record.put(...)` rejects — a populated parent relationship object, a child
subquery, a formula / roll-up-summary / system / read-only field — through a
`JSON.serialize` / `JSON.deserialize` round-trip, so the code under test sees them
exactly as it would after a real `SELECT`.

It runs **after** generation, returns a **`List<SObject>` of new instances**, and
never touches the originals or the records `DEFERRED` back-fills Ids onto.

▶ Runnable: `XFTY_Ex_EnrichmentTest`

---

## `injectAll` — everything the graph holds

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setQuantityPerTemplate(2)
    .supplyBundle();

List<Contact> contacts = (List<Contact>) bundle.injectAll(Contact.Id);
contacts[0].Account.Name;     // the generated ancestor - was a null-pointer
```

`injectAll(field)` grafts **every generated ancestor** (up to the SOQL parent-hop
limit) **and one level of every generated child collection** reachable from
`field`. It **throws** — rather than returning an untouched bundle — when the
graph has no generated ancestor or child to inject (e.g. a Provider run with
`setInclusivity(NONE)` and no `with(...)`).

`injectAllParents(field)` and `injectAllChildren(field)` do one direction only.
None of the three take a config; to configure a broad pass, call `inject` with
the matching breadth start:

```apex
bundle.inject(Contact.Id, XFTY_InjectConfig.allParents().parentDepth(2));
```

### Which list `field` selects

`field` names the list *in this bundle* whose records get enriched:

| `field` is… | records enriched | its own graft sources |
|---|---|---|
| the **primary** field (`Contact.Id`) | `bundle.primaryRecords()` | the primaries' generated ancestors + `with(...)` children |
| a **generated-ancestor** field (`Contact.AccountId`) | `bundle.getList(Contact.AccountId)` — the Accounts, 1:1 with the primaries | those Accounts' own generated ancestors + the [inverse children](#children-of-a-generated-ancestor) (the primaries that generated them) |
| a **child-relationship** field (`Case.ContactId` after `withChildren`) | `bundle.getChildList(Case.ContactId)` | each child's own generated ancestors + its `with(...)` children |

Any other field throws, naming the fields the bundle actually holds.

---

## `inject(field, config)` — name exactly what you want

Most tests want a focused graph, not everything — and `injectAll` pays one
serialize round-trip **per graph level**, which a tight config avoids.

```apex
// one child collection, nothing else
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectChild(Contact.AccountId);

bundle.inject(Account.Id, config);
```

```apex
// a read-only field on the record, and a roll-up two hops up
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectValue(Contact.LastActivityDate, lastActivity.date())
    .injectValue(new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue }, 7500000);

bundle.inject(Contact.Id, config);
```

<!-- sketch -->
```apex
// naming a deep leaf materialises every intermediate relationship object -
// one call for the whole chain, the same walk as bundle.getValue(path)
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectParent(new List<SObjectField>{ Case.ContactId, Contact.AccountId, Account.ParentId });
```

### The config: a breadth, then refiners

`XFTY_InjectConfig` starts from a **breadth**:

| Start | |
|---|---|
| `XFTY_InjectConfig.nothing()` | nothing is injected unless a refiner names it |
| `XFTY_InjectConfig.allParents()` | every generated ancestor (to `parentDepth`) |
| `XFTY_InjectConfig.allChildren()` | one level of every generated child collection |
| `XFTY_InjectConfig.everything()` | both — what `injectAll` uses |

then layers refiners on it:

| Refiner | Effect |
|---|---|
| `.injectParent(path)` | inject the ancestor at `path` **and every hop to it**. `path` is relationship fields from the working record. |
| `.injectChild(path)` | inject a child collection. `path` is a **single** child-lookup field (`{ Case.ContactId }`); a longer path throws — see [limits](#limits-and-gotchas). |
| `.excludeParent(path)` / `.excludeChild(path)` | drop any effective path that has `path` as a prefix — prune a subtree from a breadth start. |
| `.injectValue(SObjectField field, Object value)` | force `value` onto `field` on the **working record** — the formula / roll-up / system / read-only case. |
| `.injectValue(List<SObjectField> path, Object value)` | force `value` onto the field at the end of `path`, on a record several hops up. Materialises the chain to that record automatically. |
| `.parentDepth(n)` | cap the ancestor climb. Default: 5 (the SOQL limit). |
| `.childDepth(n)` | reserved; only `1` is supported (a SOQL subquery cannot nest). `n > 1` throws. |
| `.breakSoqlLimits()` | let `parentDepth` and the `injectParent` path lengths exceed 5. Past that point the injected shape is no longer something one `SELECT` could return — on you. |

```apex
// broad start, capped, one subtree pruned
XFTY_InjectConfig config = XFTY_InjectConfig.everything()
    .parentDepth(2)
    .excludeParent(new List<SObjectField>{ Contact.AccountId });

bundle.inject(Contact.Id, config);
```

A forced `value` may be a literal or an `XFTY_ValueExpressionIntf` (resolved
through `get()`). It **cannot** be a context-aware expression — the pass has no
generation context to give it.

---

## Children of a generated ancestor

When XFTY generates an `Account` *because* a `Contact` asked for it, that
Account's `Contacts` subquery is the Contact that generated it — the inverse of
the 1:1 parent alignment. `injectAll` / `allChildren` on a generated-ancestor
field grafts it:

```apex
List<Account> generatedAccounts = (List<Account>) bundle.injectAll(Contact.AccountId);
generatedAccounts[0].Contacts.size();   // 1 - the Contact that generated this Account
```

A [shared ancestor](shared-ancestors.md) returns the **several** children that
resolved to it. `bundle.primaryRowsResolvingTo(relationshipField, ancestorRow)`
→ `List<Integer>` exposes that inverse directly (matched on the foreign key when
Ids exist, else the 1:1 position).

---

## `XFTY_SObjectInjector` — the round-trip on its own

The graft mechanism is public and needs no bundle — reach for it when you have a
plain `List<SObject>` and want to write something the API rejects:

```apex
List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
    .relationship('Account', accounts)
    .value(Contact.CreatedDate, Datetime.newInstance(2020, 1, 1, 0, 0, 0))
    .result();
```

<!-- sketch -->
```apex
XFTY_SObjectInjector.inject(contacts)
    .relationship('Account', accountsAligned1to1)      // one Account per contact (null for "no parent on this row")
    .childRelationship('Cases', casesPerContact)       // List<List<SObject>>, one list per contact
    .value(Contact.LastName, 'same on every row')
    .valuePerRow(Contact.Department, deptPerRow)       // one value per contact
    .result();
```

- Every graft must align 1:1 with the records — a mismatch throws a clear error
  naming the graft.
- `relationship` / `childRelationship` take the **relationship name**
  (`'Account'`, `'Parent'`, `'Contacts'`, `'Foo__r'`), not a field token. Inside
  `inject` / `injectAll` the name is resolved from the field for you.
- `result()` does exactly **one** `JSON.serialize` and **one** `JSON.deserialize`
  over the whole list, regardless of row or graft count. Inputs are untouched.

---

## Limits and gotchas

### `MOCK`-only

A value or relationship that exists only because it was forced in will **not**
survive a real `insert` + recalculation — it comes back as `null`, or whatever
the platform computes. So a test that uses `inject` is inherently `MOCK`-only;
it cannot be flipped to `NOW`. See
[unit-vs-integration](advanced/unit-vs-integration.md) point 4.

### One child level

`injectAll` / `injectChild` graft **one** level of child collection — the direct
children of the working records. Grandchildren from nested
`withChildren(...).with(...)` are **not** injected, because a SOQL subquery
cannot nest. `childDepth(n > 1)` and a multi-hop `injectChild` path both throw.
To reach a deeper collection, enrich it in its own pass:

<!-- sketch -->
```apex
XFTY_DummySObjectBundle contacts = bundle.getChildBundle(Contact.AccountId).injectAllChildren(Contact.Id);
```

### Runs after generation

- **Not visible to generation.** An injected value cannot feed a
  [context-aware value](context-aware-values.md) — that pass is already over.
- **Insert mode is not policed.** It reads off the bundle, so it works after any
  mode. `NOW` is a pointless pairing (you could `SELECT`). Under `DEFERRED`
  **before** `flush()` the data is thin — no Ids, FKs only partly wired — and the
  pass logs a warning rather than failing.

### Snapshot semantics

An injected parent / subquery is a fixed copy. Code under test that mutates it
and expects re-query behaviour will not see the change.

### Navigate off the SObjects

`inject` / `injectAll` return a plain `List<SObject>` — the enriched target
records. Read the injected parents, subqueries and scalars **off those SObject
instances** (`contact.Account.Name`, `account.Contacts`), which is the whole
point; there is no bundle to navigate.

### Cost

One `serialize` + one `deserialize` **per graph level**, over the whole list at
that level — not per record. So width is cheap; cost climbs with **depth**
(`parentDepth`) and with **total payload size** (records × fields serialized),
and a very wide-and-deep `injectAll` can approach the heap and CPU ceilings. A
tight `inject(field, config)` that names only the paths it needs pays for only
those. Numbers: [volume-and-limits](../reference/volume-and-limits.md).

### Not exercised

Polymorphic relationship fields (`WhoId` / `WhatId`), compound fields (address,
`Location`) and `Blob` fields in the round-trip are not covered by tests yet —
they may need care. Report anything that misbehaves.

See also: [bundles](bundles.md) · [child-records](child-records.md) ·
[value-expressions](value-expressions.md) ·
[unit-vs-integration](advanced/unit-vs-integration.md)
