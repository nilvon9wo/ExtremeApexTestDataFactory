# Seeding an Org — `XFTY_Seeder.seed(bundle)`

> **Depends on a Salesforce preview.** This feature rests on **Apex Integration
> Tests** (`@IntegrationTest`) — a Winter '27 *developer preview*. It runs only in
> scratch orgs today, and Salesforce may change how it behaves before it ships.
> XFTY's own surface here is deliberately tiny — one method and a result object —
> so that if the preview shifts, this is a small thing to re-fit.
>
> Built and proven: the direct-DML path below. Not built: a Bulk API path for
> volumes past one transaction.

XFTY normally builds data *for a test* and rolls it back. `XFTY_Seeder` builds
data that **stays** — a scratch org (or, once the preview widens, a sandbox)
populated with representative records from the same Providers your tests use.

## Why `@IntegrationTest`

XFTY is `@IsTest` code, which cannot commit data outside a test transaction. A
Salesforce **Apex Integration Test** can: `@IntegrationTest` methods run real DML
with **no automatic rollback**. `@IntegrationTest` classes cannot also be
`@IsTest`, but they *can* call `@IsTest` code — so they can drive XFTY.

## Do you even need `XFTY_Seeder`?

Not strictly. Inside an `@IntegrationTest` method, a Provider run in
`XFTY_InsertModeEnum.NOW` inserts its graph and — with no rollback — it stays.
`XFTY_Seeder.seed(bundle)` adds two things `NOW` does not give you:

- **best effort** — one record failing a validation rule, a duplicate rule or a
  permission check does not abort the whole graph;
- **an audit** — `XFTY_SeedResult` tells you exactly what landed and what did not.

For a handful of clean records, `NOW` is fine. For a real seed, use the seeder.

## Generate with `LATER`

`XFTY_Seeder.seed` inserts the records itself, so the bundle it is handed must
carry **no Ids** — `insert` rejects a record that already has one, real or mock.
Generate with `XFTY_InsertModeEnum.LATER`: it builds the whole graph and inserts
nothing (identical to `NEVER`), and the name says why — *something else will
persist these*. `MOCK` (fake Ids), `NOW` and `DEFERRED` (real Ids) all leave Ids
on the records and are the wrong input to the seeder.

▶ Runnable: `XFTY_Ex_OrgSeedingTest`

<!-- sketch -->
```apex
@IntegrationTest
private class SeedMyScratchOrg {

    private static final MyProjectLookup LOOKUP = new MyProjectLookup();

    @IntegrationTest
    static void seedAccountsAndContacts() {
        XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
            .setInsertMode(XFTY_InsertModeEnum.LATER)
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
    .setInsertMode(XFTY_InsertModeEnum.LATER)
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

It does **not** police the bundle. A value you `inject`ed that a real `insert`
rejects (a formula field, a system field) is left for the platform to refuse —
and `XFTY_SeedResult` tells you it did. A `LATER` bundle with no enrichment gives
the cleanest result.

A record that already carries an Id (one you seeded earlier, or a
[shared ancestor](shared-ancestors.md) you pre-inserted and registered with
`XFTY_SharedAncestor.put(name, insertedRecord)`) is treated as an anchor:
children point at it, it is not re-inserted, and it is not in the counts.

[Shared ancestors](shared-ancestors.md) declared the usual way —
`.putRequired(field, XFTY_SharedAncestor.get(name))` — seed correctly: the shared
record is inserted **once** and every dependent points at it.

## `XFTY_SeedResult`

| Member | |
|---|---|
| `attemptedCount()` | records sent to the database (the graph minus anchors) |
| `savedCount()` / `failedCount()` | how many landed / were rejected |
| `isFullySeeded()` | `failedCount() == 0` |
| `savedRecords()` / `failedRecords()` | the records, in graph order |
| `errors()` | one line per rejected record — SObject type, status code, platform message |

## Verifying it worked

A passing `@IntegrationTest` only means the code ran. Confirm the data is really
there from **outside** the test — a plain `sf data query`, or a later
`@IntegrationTest` method that re-queries — since a seed's whole point is data
that outlives the transaction.

```bash
sf data query -o <scratch-org> --query "SELECT Name, (SELECT LastName FROM Contacts) FROM Account"
```

## Re-running

A seed is **not idempotent** — run it twice and you get two sets of records, and
duplicate rules will start rejecting the second run (reported in `errors()`, not
thrown). To reset, delete in another `@IntegrationTest` method first (there is no
rollback, so the delete sticks too).

## Limits

- **Scratch orgs only** for now (the `@IntegrationTest` preview).
- **One transaction.** The per-transaction DML-row (10,000) and CPU ceilings
  apply; split a large seed across several `@IntegrationTest` methods.
- `@IntegrationTest` runs **asynchronously** and **one at a time**.
- A **cyclic** set of lookups (no order lands every parent before its child)
  throws — best effort covers row failures, not an impossible insert order.
- No `@TearDown` — the point is that the data survives.

See also: [insert-modes](insert-modes.md) ·
[unit-vs-integration](advanced/unit-vs-integration.md)
