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

▶ Runnable: `XFTY_Ex_BundlesTest`

See also: [relationships](relationships.md) · [generating-records](generating-records.md)
