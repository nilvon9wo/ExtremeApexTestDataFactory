# Seeding an Org — `XFTY_Seeder.seed(bundle)`

> **Preview.** Relies on Salesforce **Apex Integration Tests** (`@IntegrationTest`),
> a Winter '27 developer preview that currently runs only in scratch orgs. The
> DML path below is proven; the Bulk API path (for larger volumes) is not built
> yet.

XFTY normally builds data *for a test* and rolls it back. `XFTY_Seeder` builds
data that **stays** — a scratch org (or, once the preview widens, a sandbox)
populated with representative records from the same Providers your tests use.

## Why `@IntegrationTest`

XFTY is `@IsTest` code, which cannot commit data outside a test transaction. A
Salesforce **Apex Integration Test** can: `@IntegrationTest` methods run real DML
with **no automatic rollback**. `@IntegrationTest` classes cannot also be
`@IsTest`, but they *can* call `@IsTest` code — so they can drive XFTY.

▶ Runnable: `XFTY_Ex_OrgSeedingTest`

<!-- sketch -->
```apex
@IntegrationTest
private class SeedMyScratchOrg {

    private static final MyProjectLookup LOOKUP = new MyProjectLookup();

    @IntegrationTest
    static void seedAccountsAndContacts() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
            .setInsertMode(XFTY_InsertModeEnum.NEVER)
            .setQuantityPerTemplate(50)
            .withChildren(Contact.AccountId, 5)
            .supplyBundle();

        XFTY_SeedResult result = XFTY_Seeder.seed(bundle);
        Assert.isTrue(result.isFullySeeded(), String.valueOf(result.errors()));
    }
}
```

Run it with `sf apex run test --class-names SeedMyScratchOrg`. The 50 Accounts and
250 Contacts are in the org afterward — verify with a plain `sf data query`.

The seed call itself, minus the `@IntegrationTest` wrapper:

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.NEVER)
    .withChildren(Contact.AccountId, 5)
    .supplyBundle();

XFTY_SeedResult result = XFTY_Seeder.seed(bundle);
System.debug(result.savedCount() + ' saved, ' + result.failedCount() + ' failed: ' + result.errors());
```

## What `seed` does

`XFTY_Seeder.seed(bundle)` persists **everything the bundle holds** — generated
ancestors, the primaries, downward `with(...)` children, every SObjectType — in
one `insert` per dependency layer, pointing each lookup at its parent's new Id.

It is **best effort**: a record that trips a validation rule, a required field, a
duplicate rule or a permission check is *reported*, not thrown, and the rest of
the graph still lands.

It does **not** police the bundle. A mock Id, or a value you `inject`ed that a
real `insert` rejects, is left for the platform to refuse — and `XFTY_SeedResult`
tells you it did. Seed from a bundle generated in `NEVER` mode (real structure,
no Ids, no injected read-only values) for the cleanest result.

## `XFTY_SeedResult`

| Member | |
|---|---|
| `attemptedCount()` | records sent to the database |
| `savedCount()` / `failedCount()` | how many landed / were rejected |
| `isFullySeeded()` | `failedCount() == 0` |
| `savedRecords()` / `failedRecords()` | the records, in graph order |
| `errors()` | one line per rejected record — SObject type, status code, platform message |

## Limits

- **Scratch orgs only** for now (the `@IntegrationTest` preview).
- **One transaction.** The per-transaction DML-row (10,000) and CPU ceilings
  apply; split a large seed across several `@IntegrationTest` methods.
- `@IntegrationTest` runs **asynchronously** and **one at a time**.
- No `@TearDown` — the point is that the data survives.

See also: [insert-modes](insert-modes.md) ·
[unit-vs-integration](advanced/unit-vs-integration.md)
