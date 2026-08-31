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

A Bundle may itself contain child Bundles, one per generated relationship.

```apex
XFTY_DummySObjectBundle opportunityBundle = bundle.getBundle(OpportunityLineItem.OpportunityId);
List<Account> accounts = (List<Account>) opportunityBundle.getList(Opportunity.AccountId);
```

```text
Bundle
├── OpportunityLineItem
└── Opportunity
     └── Account
```

Use `getList(field)` for the related records themselves; `getBundle(field)` for
the entire subgraph beneath them.

> `getBundle(field)` returns null for a [shared-ancestor](shared-ancestors.md)
> field today — use `getList(field)`.

▶ Runnable: `XFTY_Ex_BundlesTest` _(pending — Pass B)_

See also: [relationships](relationships.md) · [generating-records](generating-records.md)
