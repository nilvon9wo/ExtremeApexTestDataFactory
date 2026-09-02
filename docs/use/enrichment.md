# Enriching for the Code Under Test — `inject` / `injectAll`

A generated graph puts related records on the **bundle** — `bundle.getBundle(...)`
chains, `bundle.getValue(path)`. Code under test can't reach those: it does
`contact.Account.Name` or `account.Contacts` straight off the SObject, and an
in-memory SObject has neither until something writes them.

`inject` re-expresses the parts of the graph the bundle already holds in the
shape `record.put(...)` rejects — a populated parent relationship object, a child
subquery, a formula / roll-up / system / read-only field — through a
`JSON.serialize` / `JSON.deserialize` round-trip, so the code under test sees
them exactly as it would after a real `SELECT`.

It runs **after** generation, returns a **new** bundle of **new** instances, and
never touches the originals.

▶ Runnable: `XFTY_Ex_EnrichmentTest`

---

## `injectAll` — everything the graph holds

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setQuantityPerTemplate(2)
    .supplyBundle();

XFTY_DummySObjectBundle enriched = bundle.injectAll(Contact.Id);

List<Contact> contacts = (List<Contact>) enriched.getList(Contact.Id);
contacts[0].Account.Name;     // the generated ancestor - was a null-pointer
```

`injectAll(field)` grafts every generated ancestor **and** every generated child
collection reachable from `field`, to the depth a single SOQL query could return.
It **throws** if the graph has nothing to inject.

`injectAllParents(field)` / `injectAllChildren(field)` do one direction only:

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .withChildren(Contact.AccountId, 3)
    .supplyBundle();

XFTY_DummySObjectBundle enriched = bundle.injectAllChildren(Account.Id);
Account enrichedAccount = (Account) enriched.getList(Account.Id)[0];
enrichedAccount.Contacts.size();   // 3
```

`field` picks which list in the bundle to enrich: the primary field, a generated
ancestor field (`Contact.AccountId` — enriches the Accounts), or a child field.

---

## `inject(field, config)` — name exactly what you want

Most tests want a focused graph, not everything — and `injectAll` pays a
serialize round-trip per graph level, which `inject` with a tight config avoids.

```apex
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectChild(new List<SObjectField>{ Contact.AccountId });

XFTY_DummySObjectBundle enriched = bundle.inject(Account.Id, config);
```

```apex
// a read-only field on the record, and a roll-up two hops up
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectValue(Contact.LastActivityDate, lastActivity.date())
    .injectValue(new List<SObjectField>{ Contact.AccountId, Account.AnnualRevenue }, 7500000);

XFTY_DummySObjectBundle enriched = bundle.inject(Contact.Id, config);
```

<!-- sketch -->
```apex
// naming a deep leaf materialises every intermediate relationship object -
// one call for the whole chain, the same walk as bundle.getValue(path)
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectParent(new List<SObjectField>{ Case.ContactId, Contact.AccountId, Account.ParentId });
```

### Start broad, then prune

`XFTY_InjectConfig` starts from a **breadth** and layers refiners on it:

| Start | |
|---|---|
| `XFTY_InjectConfig.nothing()` | name everything you want |
| `XFTY_InjectConfig.allParents()` | every generated ancestor |
| `XFTY_InjectConfig.allChildren()` | every generated child collection |
| `XFTY_InjectConfig.everything()` | both — what `injectAll` uses |

| Refiner | |
|---|---|
| `.injectParent(path)` / `.injectChild(path)` | add a path (and its hops) |
| `.excludeParent(path)` / `.excludeChild(path)` | prune a subtree from a breadth start |
| `.injectValue(field, value)` | a forced scalar on the working record |
| `.injectValue(path, value)` | a forced scalar on a record `path` reaches |
| `.parentDepth(n)` / `.childDepth(n)` | cap the climb (default: the SOQL limit) |
| `.breakSoqlLimits()` | allow the depths and path lengths past what one SOQL could return |

```apex
XFTY_InjectConfig config = XFTY_InjectConfig.everything()
    .excludeParent(new List<SObjectField>{ Contact.AccountId });

XFTY_DummySObjectBundle enriched = bundle.inject(Contact.Id, config);
```

A `value` may be a literal or an `XFTY_ValueExpressionIntf` (resolved through
`get()`); it cannot be a context-aware expression — the pass has no generation
context.

---

## Children of a generated ancestor

When XFTY generates an `Account` *because* a `Contact` asked for it, that
Account's `Contacts` subquery is the Contact that generated it — the inverse of
the 1:1 parent alignment. `injectAll` / `allChildren` on a generated-ancestor
field grafts it:

```apex
XFTY_DummySObjectBundle enriched = bundle.injectAll(Contact.AccountId);
Account generatedAccount = (Account) enriched.getList(Contact.AccountId)[0];
generatedAccount.Contacts.size();   // 1 - the Contact that generated this Account
```

A [shared ancestor](shared-ancestors.md) returns the several children that
resolved to it. `bundle.primaryRowsResolvingTo(relationshipField, ancestorRow)`
exposes that inverse directly.

---

## `XFTY_SObjectInjector` — the round-trip on its own

The graft mechanism is public and needs no bundle:

```apex
List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
    .relationship('Account', accounts)
    .value(Contact.CreatedDate, Datetime.newInstance(2020, 1, 1, 0, 0, 0))
    .result();
```

<!-- sketch -->
```apex
XFTY_SObjectInjector.inject(contacts)
    .childRelationship('Cases', casesPerContact)       // List<List<SObject>>, one list per contact
    .valuePerRow(Contact.LastName, namePerRow)         // one value per contact
    .result();
```

`result()` does **one** `JSON.serialize` and **one** `JSON.deserialize` for the
whole list, regardless of row or graft count. Misaligned grafts throw a clear
error. Inputs are untouched.

---

## Caveats

- **MOCK-only.** A value or relationship that only exists because the test forced
  it will not survive a real `insert` + recalculation — see
  [unit-vs-integration](advanced/unit-vs-integration.md) point 4. Using `inject`
  flags the test as `MOCK`-only.
- **Not visible to generation.** The pass runs after generation is over; an
  injected value cannot feed a [context-aware value](context-aware-values.md).
- **Snapshot.** An injected parent / subquery is a fixed copy; code that mutates
  it and re-queries will not see the change.
- **`DEFERRED` before `flush()`** gives thin data (no Ids, FKs partly wired) — a
  warning, not an error.
- **Cost.** One serialize + deserialize per enriched graph level. The config
  bounds it; a deep `injectAll` over a large graph is not free.
- **The returned bundle is a carrier.** `enriched.getList(field)` is the enriched
  instances; navigate the relationships off the SObjects, not with
  `enriched.getBundle(...)`.

See also: [bundles](bundles.md) · [child-records](child-records.md) ·
[value-expressions](value-expressions.md)
