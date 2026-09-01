# Building Data Across Helper Methods

The primary replacement for `@TestSetup`
([why](../../reference/salesforce-considerations.md)) is a **`static` fixture on
the test class** — Apex re-runs static initialisers for each test method, so the
fixture is built fresh per method, declared once, and visible right next to the
tests:

```apex
private static final XFTY_DummySObjectProviderLookup PROVIDER_LOOKUP = new XFTY_DefaultSObjectProviderLookup();

private static final List<Account> SHARED_ACCOUNTS = new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setQuantityPerTemplate(3)
    .supplyList();
```

This page is for the narrower case a `static` fixture cannot cover: shared setup
built in **ordered steps, inserted once**. The tool for it is a chain of helper
methods plus the [`DEFERRED`](../deferred-insert.md) insert mode — build
everything, `flush()` once.

### `DEFERRED` in a `static` fixture: use a `static {}` block

`DEFERRED` only pays off if something calls `XFTY_DeferredInserter.flush()`. A
static **initialiser block**, placed *after* the fixture variables it depends on,
is that place — it runs once per test method, after those variables are built:

```apex
private static XFTY_DummySObjectBundle sharedAccounts;
private static XFTY_DummySObjectBundle sharedContacts;

static {
    sharedAccounts = new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();
    sharedContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .supplyBundle();
    XFTY_DeferredInserter.flush();   // one insert phase for both, before any test method runs
}
```

Order matters — the block runs in declaration order with everything else, so it
must come *below* the variables. Two ordered steps with their own `flush()`
between them go in the same block. `System.runAs(...)` belongs in the test
methods, not the block.

> **Verify this on your org.** Salesforce re-runs static initialisation for each
> test method and rolls back all of a test method's DML (static init included),
> which is what makes this work. Nimbus does **not** roll back static-initialiser
> DML between test methods, so this specific form cannot be checked locally —
> `XFTY_Ex_Adv_DeepSetupChainsTest` proves the helper form instead.

Use the **per-method helper form below** when the setup order depends on the test
method rather than being fixed — a method that flushes, reads an Id, then builds
more, when a different method needs a different sequence.

---

## The pattern

Each helper **returns its bundle** so the test reads generated values straight
off it — no `SELECT` to re-fetch what XFTY just built:

```apex
private static XFTY_DummySObjectBundle seedAccounts() {
    return new XFTY_DummySObjectProvider(Account.SObjectType, PROVIDER_LOOKUP)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();
}

private static XFTY_DummySObjectBundle seedContacts() {
    return new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
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
XFTY_DummySObjectBundle seededContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, PROVIDER_LOOKUP)
    .setOverrideTemplate(new Contact(AccountId = firstSeededAccountId))
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setQuantityPerTemplate(4)
    .supplyBundle();
XFTY_DeferredInserter.flush();

Assert.areEqual(firstSeededAccountId, seededContacts.getList(Contact.Id)[0].AccountId);
```

▶ Runnable: `XFTY_Ex_Adv_DeepSetupChainsTest`
