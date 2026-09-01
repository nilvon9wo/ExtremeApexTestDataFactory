# Building Data Across Helper Methods

XFTY discourages `@TestSetup`
([why](../../reference/salesforce-considerations.md)). The replacement for
"shared setup built in several steps" is a chain of helper methods plus the
[`DEFERRED`](../deferred-insert.md) insert mode — build everything, insert once.

---

## The pattern

Each helper **returns its bundle** so the test reads generated values straight
off it — no `SELECT` to re-fetch what XFTY just built:

```apex
private static XFTY_DummySObjectBundle seedAccounts() {
    return new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();
}

private static XFTY_DummySObjectBundle seedContacts() {
    return new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
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
XFTY_DummySObjectBundle seededContacts = new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
    .setOverrideTemplate(new Contact(AccountId = firstSeededAccountId))
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .setQuantityPerTemplate(4)
    .supplyBundle();
XFTY_DeferredInserter.flush();

Assert.areEqual(firstSeededAccountId, seededContacts.getList(Contact.Id)[0].AccountId);
```

▶ Runnable: `XFTY_Ex_Adv_DeepSetupChainsTest`
