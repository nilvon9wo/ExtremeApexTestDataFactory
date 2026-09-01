# Child Records (`with` / `withChildren`)

XFTY generates **upward** by default: ask for a `Contact` and it generates the
`Account` the Contact needs. `with(...)` generates the other direction — records
that hang **below** a Provider's primaries.

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Title = 'Buyer')).setQuantity(3))
    .supplyBundle();

Account account = (Account) bundle.primaryRecords()[0];
List<Contact> contacts = (List<Contact>) bundle.getChildList(Contact.AccountId);
// 1 Account, 3 Contacts, each contact.AccountId == account.Id
```

---

## `XFTY_SObjectChildProvider`

One child collection. The child SObjectType comes from the **relationship
field** — `Contact.AccountId` is a field on `Contact`, so the children are
Contacts. There is no type argument to keep in sync.

```apex
new XFTY_SObjectChildProvider(Contact.AccountId)                       // blank template
new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Title='Buyer'))
```

| Method | |
|---|---|
| `.setQuantity(Integer)` | children per primary (default 1) |
| `.put(field, strategy \| literal \| contextAwareStrategy)` | as on the main Provider |
| `.putRequired(field, relationship)` / `.putOptional(field, relationship)` | the child's own relationships |
| `.setInsertMode(XFTY_InsertModeEnum)` | default: the parent Provider's. **Cannot mix mock Ids with real DML** (parent `NOW` + child `MOCK` throws). |
| `.setInclusivity(XFTY_InsertInclusivityEnum)` | default: the parent Provider's. Governs the child's **own other** relationships only. |
| `.withVariant(XFTY_LookupKeyIntf)` | pin the child Provider variant |
| `.with(XFTY_SObjectChildProvider)` | nest grandchildren (below) |

## Attaching it

| On `XFTY_DummySObjectProvider` | |
|---|---|
| `.with(childProvider)` | add a child collection — **repeatable and additive** |
| `.withChildren(field, n)` | shortcut for `.with(new XFTY_SObjectChildProvider(field).setQuantity(n))` |
| `.withChild(field)` | shortcut for one child |

The relationship field must actually point at the Provider's type — hanging
`Case.AccountId` off a `Contact` Provider throws.

```apex
new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department='Sales')).setQuantity(3))
    .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department='Support')).setQuantity(2))  // additive
    .with(new XFTY_SObjectChildProvider(Case.AccountId).setQuantity(4))                                        // another type
```

---

## Reading the children

| Call | Returns |
|---|---|
| `bundle.getChild(field)` | the first child for that relationship field |
| `bundle.getChildList(field)` | every child for that field, merged across configs, in the documented order |
| `bundle.getChildBundle(field)` | one `XFTY_DummySObjectBundle` of all those children — navigate on to the children's **own** generated parents, or to grandchildren |
| `bundle.childRelationshipFields()` | every child relationship field populated |

### Order of `getChildList`

Child rows are produced **config declaration order, then primary order, then
per-primary quantity** — the same "quantity outside the loop" rule as
`setQuantityPerTemplate` (2 templates × quantity 2 → A, B, A, B).

For two primaries `P0, P1`, config A (quantity 2) then config B (quantity 1):

```
A/P0  A/P0  A/P1  A/P1   B/P0  B/P1
```

### Working example

```apex
new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setOverrideTemplateList(new List<Account>{ new Account(), new Account() })
    .setQuantityPerTemplate(4)                                                   // 8 Account primaries
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department='A')).setQuantity(3))
    .with(new XFTY_SObjectChildProvider(Contact.AccountId, new Contact(Department='B')).setQuantity(2))
    .supplyBundle();
// 8 primaries × 3 → 24 department-A Contacts ; 8 × 2 → 16 department-B ; 40 total
```

Proven by `XFTY_ChildGenerationTest.twoConfigsOnTheSameFieldAreAdditiveAndMultiplyWithTemplateQuantity`.

---

## Grandchildren

`XFTY_SObjectChildProvider` nests:

```apex
new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .with(
        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(3)
            .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(2))
    )
    .supplyBundle();
// per Account: 3 Contacts, and 2 Cases under each Contact (6 Cases)
```

Read them with `bundle.getChildBundle(Contact.AccountId).getChildList(Case.ContactId)`.

The row count **multiplies** down the tree — a governor-budget warning fires if
generation gets expensive.

---

## Insert modes

`setInsertMode` / `setInclusivity` on the parent Provider flow through to every
level unless a child overrides them.

| Parent mode | Children |
|---|---|
| `NOW` | primaries inserted, then children (and grandchildren) inserted with real FKs |
| `MOCK` | everything gets mock Ids; FKs wired |
| `NEVER` | nothing persisted; children have a `null` back-reference (no primary Id to point at) — a child can still `setInsertMode(NOW)` to insert itself |
| `DEFERRED` / `.depthBatched()` | the **whole** child subtree joins the same deferred graph; `XFTY_DeferredInserter.flush()` (or the end of the `depthBatched` call) inserts every level in dependency order and back-fills the FKs |

Each child still generates its **own** other required parents (at its
inclusivity) — a `Case` child that needs a `Contact` gets one, and that Contact
gets its Account.

▶ Runnable: `XFTY_ChildGenerationTest`

See also: [relationships](relationships.md) · [shared-ancestors](shared-ancestors.md)
(the opposite — many children, **one** shared parent) · [bundles](bundles.md)
