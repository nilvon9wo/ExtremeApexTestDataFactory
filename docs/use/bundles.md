# Bundles

Every generation operation ultimately produces a `XFTY_DummySObjectBundle`. Rather
than returning only the requested records, a Bundle contains the **entire object
graph** created during generation — the requested records, directly related
records, indirectly related records, and the relationships between them.

Bundles make every generated object available without additional SOQL.

---

## Getting a Bundle

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supplyBundle();
```

`supply()` and `supplyList()` are conveniences that pull the primary records out
of the same Bundle — use `supplyBundle()` when the test needs related records
too.

---

## Extracting lists

Lists are retrieved using the **field that produced them**.

```apex
List<Contact> contacts = (List<Contact>) bundle.getList(Contact.Id);
List<Account> accounts = (List<Account>) bundle.getList(Contact.AccountId);
```

`bundle.getList(field)` stays aligned 1:1 with the primary records — entry *i* of
`getList(Contact.AccountId)` is the Account for entry *i* of `getList(Contact.Id)`.

---

## Navigating nested Bundles

A Bundle contains a child Bundle per generated relationship, and those nest as
deep as the graph does. If the Contact's Account is itself generated with a
parent Account:

```apex
XFTY_DummySObjectBundle accountBundle = bundle.getBundle(Contact.AccountId);
XFTY_DummySObjectBundle parentAccountBundle = accountBundle.getBundle(Account.ParentId);
Account parentAccount = (Account) parentAccountBundle.getList(Account.Id)[0];
```

```text
Bundle
└── Contact
     └── Account (Contact.AccountId)
          └── Account (Account.ParentId)
```

Use `getList(field)` for the related records themselves; `getBundle(field)` for
the entire subgraph beneath them. Both are populated for a
[shared ancestor](shared-ancestors.md), whether it was generated or supplied
with `XFTY_SharedAncestor.put(...)`.

---

## Walking an ancestor path — `getValue`

When you only want one field several hops up, `getValue` walks the path so you
don't have to hold every intermediate bundle and list:

```apex
Object parentAccountName =
    bundle.getValue(new List<SObjectField>{ Contact.AccountId, Account.Name });
```

The path is one or more **relationship fields** then the **field to read**. A
second argument picks the row when the bundle has more than one primary
(`getValue(path, rowIndex)`); the no-index form is `rowIndex` 0. Any hop that was
not generated — an optional relationship the current inclusivity skipped — makes
the whole call return `null` rather than throw. It only follows generated
**ancestors**; for children use `getChildBundle(field)` and navigate from there.
`XFTY_CopyFromAncestorExpression` is this same walk wrapped as a context-aware value.

---

## Generated children

Downward generation ([`with` / `withChildren`](child-records.md)) hangs children
off the primaries. Read them back off the same bundle:

```apex
Account account            = (Account) bundle.primaryRecords()[0];
List<Contact> contacts     = (List<Contact>) bundle.getChildList(Contact.AccountId);
XFTY_DummySObjectBundle kids = bundle.getChildBundle(Contact.AccountId);   // navigate on to grandchildren / the children's own parents
```

| Call | Returns |
|------|---------|
| `bundle.getChild(field)` | the first child for that relationship field |
| `bundle.getChildList(field)` | every child for that field, merged across configs, in declaration → primary → quantity order |
| `bundle.childRecordsOf(parentRowIndex, field)` | just the children of `primaryRecords()[parentRowIndex]` |
| `bundle.getChildBundle(field)` | one bundle of all those children, for navigating deeper |
| `bundle.childRelationshipFields()` | every child relationship field populated |

There is no `getChildValue(path)` — downward, one primary fans out to *many*
children, so a per-parent read returns a **list**, not a value. Use
`childRecordsOf(parentRowIndex, field)` (it reads the recorded parent-of-child
map, so you never line rows up by arithmetic) and pull fields off the records it
returns. Full detail — ordering, multiple child configs, grandchildren — is in
[child-records](child-records.md).

`bundle.primariesResolvingTo(relationshipField, ancestorRowIndex)` is the
upward counterpart of `childRecordsOf` — the primary records that were generated
pointing at that generated ancestor (a [shared ancestor](shared-ancestors.md)
returns the several that resolved to it).

---

## Enriching for the code under test

`getBundle` / `getValue` read the graph *for the test*. When the **code under
test** needs `contact.Account.Name` or `account.Contacts` off the SObject
itself, `bundle.inject(field, config)` / `injectAll(field)` write those onto new
instances via a JSON round-trip. See [enrichment](enrichment.md).

▶ Runnable: `XFTY_Ex_BundlesTest`

See also: [relationships](relationships.md) · [child-records](child-records.md) · [generating-records](generating-records.md)
