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

## The target records

Everything below talks about the **target records** — the records `inject`
operates on. `field` must be one of exactly three things the bundle recognises
(the table below); the bundle it operates on is **whichever bundle you call
`inject` on** — the one your Provider returned, *or* one you navigated into
(`bundle.getChildBundle(X).inject(...)`) — never "the root of the original
generation".

| `field` is… | target records | what they can carry |
|---|---|---|
| the **primary** field (`Contact.Id`) | `bundle.primaryRecords()` | their generated ancestors; their `with(...)` children |
| a **generated-ancestor** field (`Contact.AccountId`) | `bundle.getList(Contact.AccountId)` — the Accounts, 1:1 with the primaries | those Accounts' own ancestors; **the inverse child** — the Contacts that generated them |
| a **child-relationship** field (`Case.ContactId`, after `withChildren`) | `bundle.getChildList(Case.ContactId)` | each child's own ancestors; its own `with(...)` children |

A `field` the bundle **does not recognise** throws, naming the fields it holds. A
`field` it *does* recognise but generated **nothing** for — a relationship left
out by `setInclusivity`, a child collection of quantity 0 — has an empty target
list: `inject` returns `new List<SObject>()` and grafts nothing, it does not
throw.

---

## `injectAll` — everything the graph holds

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setQuantityPerTemplate(2)
    .supplyBundle();

List<Contact> contacts = (List<Contact>) bundle.injectAll(Contact.Id);
contacts[0].Account.Name;          // the generated ancestor - was a null-pointer
contacts[0].Account.Contacts;      // the inverse child - [ contacts[0] as a plain copy ]
```

`injectAll(field)` grafts, recursively:

- **every generated ancestor** to `parentDepth` (5), each carrying its **inverse
  child** — the record one level down that generated it;
- **one level** of every generated child collection, each child carrying **its
  own** generated ancestors.

It **throws** — rather than returning an untouched list — when the graph has no
generated ancestor or child to inject (a Provider run `setInclusivity(NONE)` with
no `with(...)`).

`injectAllParents(field)` and `injectAllChildren(field)` do one direction only.
None of the three take a config; to configure a broad pass, call `inject` with
the matching breadth start:

```apex
bundle.inject(Contact.Id, XFTY_InjectConfig.allParents().parentDepth(2));
```

---

## `inject(field, config)` — name exactly what you want

Most tests want a focused graph, not everything — and `injectAll` pays one
serialize round-trip **per graph position**, which a tight config avoids.

```apex
// one child collection, nothing else
bundle.inject(Account.Id, XFTY_InjectConfig.nothing().injectChild(Contact.AccountId));
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

| Start | Ancestors | Children |
|---|---|---|
| `XFTY_InjectConfig.nothing()` | only named | only named |
| `XFTY_InjectConfig.allParents()` | every one, to `parentDepth` | only named |
| `XFTY_InjectConfig.allChildren()` | only named | every one, to `childDepth`, + the inverse |
| `XFTY_InjectConfig.everything()` | every one everywhere | every one everywhere |

then layers refiners on it:

| Refiner | Effect |
|---|---|
| `.injectParent(path)` | inject the ancestor at `path` **and every hop to it**. `path` is relationship fields from the **target record** — it does not reach into a child's ancestors. |
| `.injectChild(childLookupField)` | inject the child collection that lookup defines (`Case.ContactId` → the target's Cases). One field, one hop. |
| `.excludeParent(path)` / `.excludeChild(childLookupField)` | drop anything an `exclude` covers from a breadth start (prefix match for parents). |
| `.injectValue(field, value)` | force `value` onto `field` on the **target record**. |
| `.injectValue(path, value)` | force `value` onto the field at the end of `path`, on a record several hops **up** (materialises the chain to it). Entry-spine only, like `injectParent`. |
| `.injectChildValue(childField, leafField, value)` | force `value` onto `leafField` on **every record** of the child collection `childField` defines. |
| `.injectChildValue(path, value)` | the same, `path` being the child-lookup hops read **downward** then the field to set — a grandchild needs `childDepth` (and `breakSoqlLimits()`) to match. |
| `.parentDepth(n)` | cap the ancestor climb. Default 5. |
| `.childDepth(n)` | how many levels of nested child collections. Default 1; **`n > 1` needs `breakSoqlLimits()`**. |
| `.breakSoqlLimits()` | let `parentDepth`, `childDepth` and the `injectParent` path length exceed what one `SELECT` could return. Past that point the injected shape is fiction the platform could never produce — on you. |

```apex
// broad start, capped, one subtree pruned
XFTY_InjectConfig config = XFTY_InjectConfig.everything()
    .parentDepth(2)
    .excludeParent(new List<SObjectField>{ Contact.AccountId });

bundle.inject(Contact.Id, config);
```

```apex
// a formula-like value on every Contact of the target Account
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectChildValue(Contact.AccountId, Contact.Description, new XFTY_IncrementingStringExpression('note'));

bundle.inject(Account.Id, config);
```

**`injectValue(path)` climbs, `injectChildValue(path)` descends.** In a
self-referential hierarchy the same field token (`Account.ParentId`) is both the
parent hop and the child hop — the method name is what fixes the direction, so
there is nothing to disambiguate:

<!-- sketch -->
```apex
XFTY_InjectConfig config = XFTY_InjectConfig.everything()
    .injectValue(new List<SObjectField>{ Account.ParentId, Account.Name }, 'the parent')
    .injectChildValue(Account.ParentId, Account.Name, 'a child');
// enriched.Parent.Name == 'the parent';  enriched.ChildAccounts[0].Name == 'a child'
```

A forced `value` — record, ancestor or child — may be:

- a **literal** (every record at that position gets it — the "they'd all compute
  the same formula" case);
- a **`List<Object>`** (one per record, in `getChildList` order; length-checked);
- an **`XFTY_ValueExpressionIntf`**, resolved *fresh per record* — so
  `new XFTY_IncrementingStringExpression('n')` gives each child a distinct value.

It **cannot** be a context-aware expression — the pass has no generation context.
A path that never reaches a record the graph produced (a typo, an ancestor or
child that was not generated, a `parentDepth` / `childDepth` too shallow) is a
**loud error**, not a silent no-op.

---

## Nested children — `childDepth`

A two-level subquery **does** survive the round-trip on a real org (SOQL can't
*query* one, but `JSON.deserialize` can *build* one). So nested `withChildren`
grandchildren are reachable — you just have to ask, because they're past what a
`SELECT` returns:

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .with(
        new XFTY_SObjectChildProvider(Contact.AccountId).setQuantity(2)
            .with(new XFTY_SObjectChildProvider(Case.ContactId).setQuantity(3))
    )
    .supplyBundle();

List<Account> accounts = (List<Account>) bundle.inject(
    Account.Id, XFTY_InjectConfig.allChildren().childDepth(2).breakSoqlLimits()
);
accounts[0].Contacts[0].Cases.size();   // 3
```

---

## Children of a generated ancestor

`bundle.primariesResolvingTo(relationshipField, ancestorRowIndex)` → `List<SObject>`
gives the primary records that were generated pointing at a given generated
ancestor — the inverse of the 1:1 parent alignment (matched on the foreign key
when Ids exist, else the 1:1 position; a [shared ancestor](shared-ancestors.md)
returns the several primaries that resolved to it). The upward counterpart of
`childRecordsOf`. Enrichment uses this to graft the inverse child subquery; it is
also useful on its own.

---

## `XFTY_SObjectInjector` — the round-trip on its own

The graft mechanism is public and needs no bundle. Full guide, with examples:
**[sobject-injector](sobject-injector.md)**.

```apex
List<Contact> enriched = (List<Contact>) XFTY_SObjectInjector.inject(contacts)
    .relationship('Account', accounts)
    .value(Contact.CreatedDate, Datetime.newInstance(2020, 1, 1, 0, 0, 0))
    .result();
```

---

## Limits and gotchas

### `MOCK` in practice

`inject` runs off the bundle, so it technically works after any insert mode — but
a value or relationship you forced in is **fiction**. After a real `insert` the
platform recomputes formulas and roll-ups, so an injected read-only field comes
back `null` or different, and code that re-queries an injected subquery sees the
database, not your copy. A test that asserts on injected data is therefore valid
only as a **`MOCK` unit test** — see
[unit-vs-integration](advanced/unit-vs-integration.md) point 4. (After `NOW` the
records already have real Ids; just `SELECT`.)

**Nothing stops you running DML on an injected record — that is deliberate, not
enforced — and it is at your own risk.** An injected instance may carry a mocked
`Id`, populated relationship objects, a snapshot subquery, and read-only /
formula values a real `insert` rejects or recomputes, so DML against one usually
**throws** (`INVALID_FIELD_FOR_INSERT_UPDATE`, *field is not writeable*,
`MALFORMED_ID` on update); when it does not, the test **passes on data the
database would never hold**. The deserialized instances are also independent
copies — mutating one end of a relationship does not update the other,
`contact.Account.Contacts[0]` is not `contact`, and the subquery does not grow
when code adds a child.

### `Blob` and compound fields

Both work. A `Blob` field can't pass through the JSON (the platform rejects a
base64 field on a typed deserialize), so it is **carried across** — captured off
the record, kept out of the round-trip, re-applied to the result:
`injectValue(Attachment.Body, aBlob)` and a pre-set `Body` both survive. (A
`Blob` on an injected *parent / child* record is dropped.)

A **compound** field takes a `Map` of its **lowercase components** — setting the
components individually does *not* compose it:

```apex
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectValue(Contact.MailingAddress, new Map<String, Object>{ 'city' => 'Portland', 'street' => '2 Oak St' });
// code under test can then read contact.MailingAddress.getCity()
```

### Depth is capped to a queryable shape by default

Enrichment can build a graph deeper than any single `SELECT` could return — a
sixth ancestor hop, a nested (grandchild) subquery. It **deliberately refuses
to**, unless you opt out: `parentDepth` defaults to 5 (the SOQL relationship-hop
limit), `childDepth` to 1 (SOQL allows no nested subquery), and an `injectParent`
/ `injectChildValue` path may not run past those. The reason is
[unit-vs-integration](advanced/unit-vs-integration.md): a shape the platform
could never produce is a landmine the day the same test runs `NOW`.

`breakSoqlLimits()` lifts the ceiling — deeper `parentDepth`, `childDepth > 1`,
longer paths. Past that point the injected structure is fiction no `SELECT` will
ever match, and keeping the test honest is on you. (The one check it does *not*
lift: `childDepth` must still reach as deep as every `injectChildValue` path —
that is an internal consistency error, not a SOQL-shape one.)

### Runs after generation

An injected value cannot feed a [context-aware value](context-aware-values.md):
that pass ran during generation and is over. To force a value that *depends* on
the graph — a formula off a parent, a roll-up off the children you just set with
`injectChildValue` — read the inputs yourself and pass a literal or a
`List<Object>`:

```apex
String parentName = (String) bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });
XFTY_InjectConfig config = XFTY_InjectConfig.nothing()
    .injectValue(Contact.Description, parentName + ' (contact)');
bundle.inject(Contact.Id, config);
```

`bundle.getValue(path[, row])`, `bundle.childRecordsOf(row, field)` and
`bundle.primariesResolvingTo(...)` are the readers for that.

Under `DEFERRED` **before** `flush()` the data is thin (no Ids, FKs partly wired)
— a warning, not an error.

### The inverse child on an ancestor is one level of plain copies

`contact` and `contact.Account.Contacts[0]` are distinct instances; the latter is
not re-enriched (`contact.Account.Contacts[0].Cases` is not populated even if
`contact.Cases` is).

### `injectParent` / `injectChild` are target-relative

They name relationships from the **target record**. They do not reach into a
child collection's ancestors — that only happens under `everything()`
(`fromAllParents`).

### Cost, and staying safe

One `serialize` + `deserialize` **per graph position visited**, over the whole
list at that position — not per record. So **width is cheap**; cost climbs with
**depth** (`parentDepth`, `childDepth`) and with **total payload size** (records
× fields serialized). `injectAll` under `everything()` visits the most positions
(every ancestor with its inverse, every child with its ancestors) — it is the
expensive mode; a tight `inject(field, config)` naming only what a test needs is
much cheaper.

The pass is wrapped in `XFTY_GovernorBudget`, so it **`System.debug(WARN)`s** when
it has eaten a large share of CPU or heap (thresholds in `XFTY_Settings__c`).

Rules of thumb, from `XFTY_EnrichmentLoadTest` (a quiet org, `MOCK`):

| Shape | Verdict |
|---|---|
| a few thousand target records × one ancestor level | comfortable |
| ~200 target records × a 5-deep ancestor chain | comfortable |
| ~50 parents × ~15 children (a ~1–2k-record subtree) | comfortable |
| `everything()` over a wide graph that is also several deep | the expensive case — watch the WARN log, or narrow the config |
| `XFTY_SObjectInjector`, ~3 000 rows, one graft | comfortable — one round-trip |

Numbers and the practical per-transaction ceilings are in
[volume-and-limits](../reference/volume-and-limits.md).

### Verified

Polymorphic relationships (`WhoId` → `Who`), compound fields, `Blob` fields,
`Datetime`, and the two-level subquery envelope are all covered by tests and
confirmed on a real Salesforce org.

See also: [sobject-injector](sobject-injector.md) · [bundles](bundles.md) ·
[child-records](child-records.md) ·
[value-expressions](value-expressions.md) ·
[unit-vs-integration](advanced/unit-vs-integration.md)
