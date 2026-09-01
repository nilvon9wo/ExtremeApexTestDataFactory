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

### Why not a `static` fixture here?

`DEFERRED` only pays off if something calls `XFTY_DeferredInserter.flush()`, and a
`static` initialiser has nowhere to put that call — the fixture would build the
graph but never insert it. You would end up calling `flush()` at the top of every
test method anyway, which is exactly the per-method helper-call this page
describes. So:

| Shared setup that… | Use |
|---|---|
| is a plain snapshot (`MOCK` / `NOW`), same for every method | a `static` fixture |
| is built in ordered steps, or a later step needs an earlier record's real Id, or one insert phase for the whole graph matters | helper methods + `DEFERRED`, called per test method |

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
