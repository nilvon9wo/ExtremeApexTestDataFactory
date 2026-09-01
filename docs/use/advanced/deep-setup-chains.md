# Building Data Across Helper Methods

The primary replacement for `@TestSetup`
([why](../../reference/salesforce-considerations.md)) is a **`static` fixture on
the test class** — Apex re-runs static initialisers for each test method, so the
fixture is built fresh per method, declared once, and visible right next to the
tests:

```apex
private static final XFTY_DummySObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();

private static final List<Account> SHARED_ACCOUNTS = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setQuantityPerTemplate(3)
    .supplyList();
```

This page is for the narrower case a `static` fixture cannot cover: shared setup
built in **ordered steps, inserted once**. The tool for it is a chain of helper
methods plus the [`DEFERRED`](../deferred-insert.md) insert mode — build
everything, `flush()` once.

### `DEFERRED` in a `static` fixture: use a `static {}` block

`DEFERRED` only pays off if something calls `XFTY_DeferredInserter.flush()`. Build
the bundles as ordinary `static` initialisers (no DML), then add **one trailing
`static {}` block** whose only job is the flush:

```apex
private static XFTY_DummySObjectBundle sharedAccounts = new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setQuantityPerTemplate(3)
    .supplyBundle();

private static XFTY_DummySObjectBundle sharedContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .supplyBundle();

static {
    XFTY_DeferredInserter.flush();   // one insert phase for both, before any test method runs
}
```

The block must come *below* the variables it flushes. `flush()` back-fills the
real Ids onto the same bundle instances, so `sharedAccounts.getList(Account.Id)[0].Id`
is populated in every test method. `System.runAs(...)` belongs in the test
methods, not the block. Equivalent: declare the variables bare and do the
`supplyBundle()` calls *and* the `flush()` inside one block.

▶ Runnable: `XFTY_Ex_Adv_StaticDeferredFixtureTest`

> **One thing still needs an org check.** Salesforce re-runs static
> initialisation for each test method and rolls back all of a test method's DML,
> static init included — that is what keeps the fixture isolated between methods.
> Nimbus (the local Apex runtime some contributors use —
> [about-nimbus](../../contribute/about-nimbus.md)) rebuilds the bundles per
> method (so bundle-based assertions are safe) but does **not** roll back the
> static-initialiser `insert`, so a
> `[SELECT COUNT()]` in a local run sees rows accumulate. Assert against the
> bundle, not the database, and confirm isolation once on a real org.

**Do not** try to hand a flushed Id from an earlier `static {}` block to a
*later* `static` variable — an earlier block reading `firstId` then a later
`sharedContacts` initialiser consuming it. Static-variable initialisers and
`static {}` blocks are not reliably interleaved in source order everywhere
(Nimbus runs every field initialiser before any block), and the moment one step
needs a real Id from a previous one, the ordering is inherently
test-method-specific. Use the **per-method helper form below** for that.

---

## The pattern

Each helper **returns its bundle** so the test reads generated values straight
off it — no `SELECT` to re-fetch what XFTY just built:

```apex
private static XFTY_DummySObjectBundle seedAccounts() {
    return new XFTY_DummySObjectProvider(Account.SObjectType, lookup)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();
}

private static XFTY_DummySObjectBundle seedContacts() {
    return new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(9)
        .supplyBundle();
}

@IsTest
static void theCodeUnderTestSeesAFullyBuiltGraph() {
    // Arrange
    XFTY_DummySObjectBundle seededAccounts = seedAccounts();
    XFTY_DummySObjectBundle seededContacts = seedContacts();
    XFTY_DeferredInserter.flush();   // one depth-batched insert phase for everything

    // Act
    // ... hand seededAccounts.getList(Account.Id) to the code under test ...

    // Assert - values read straight off the bundles, no SOQL
    List<Account> accountRecords = seededAccounts.getList(Account.Id);
    Assert.areEqual(3, accountRecords.size());
    Assert.isNotNull(accountRecords[0].Id, 'flush() back-filled the Ids onto the bundle instances');
    Assert.areEqual(9, seededContacts.getList(Contact.Id).size());
}
```

- No helper does DML — `flush()` does it all, once.
- A helper that never runs still costs nothing (a test that skips `flush()` gets
  `NEVER` semantics).
- `flush()` back-fills the real Ids **onto the same record instances the bundles
  hold**, so `seededAccounts.getList(Account.Id)[0].Id` is populated afterwards.

---

## When a later step needs an earlier record's real Id

`flush()` the earlier step, then read the Id **off its bundle** and pass it on —
still no `SELECT`:

```apex
XFTY_DummySObjectBundle seededAccounts = seedAccounts();
XFTY_DeferredInserter.flush();                                  // Accounts now have Ids

Id firstSeededAccountId = seededAccounts.getList(Account.Id)[0].Id;

// a later step that needs that Id as a value - still DEFERRED, flush again
XFTY_DummySObjectBundle laterContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setOverrideTemplate(new Contact(AccountId = firstSeededAccountId))
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setQuantityPerTemplate(4)
    .supplyBundle();
XFTY_DeferredInserter.flush();

Assert.areEqual(firstSeededAccountId, laterContacts.getList(Contact.Id)[0].get(Contact.AccountId));
```

▶ Runnable: `XFTY_Ex_Adv_DeepSetupChainsTest`
