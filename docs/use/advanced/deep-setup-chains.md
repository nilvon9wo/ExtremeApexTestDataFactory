# Building Data Across Helper Methods

XFTY discourages `@TestSetup`
([why](../../reference/salesforce-considerations.md)). The replacement for
"shared setup built in several steps" is a chain of helper methods plus the
[`DEFERRED`](../deferred-insert.md) insert mode — build everything, insert once.

---

## The pattern

```apex
private static void makeAccounts() {
    new XFTY_DummySObjectProvider(Account.SObjectType, LOOKUP)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .setQuantityPerTemplate(3)
        .supplyBundle();
}

private static void makeContacts() {
    new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
        .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
        .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
        .supplyBundle();
}

@IsTest
static void theTest() {
    makeAccounts();
    makeContacts();
    XFTY_DeferredInserter.flush();   // one depth-batched insert phase for everything
    // ... exercise the code under test
}
```

- No helper does DML — `flush()` does it all, once.
- A helper that never runs still costs nothing (a test that skips `flush()` gets
  `NEVER` semantics).

---

## When a later step needs an earlier record's real Id

`flush()` the earlier step first:

```apex
makeAccounts();
XFTY_DeferredInserter.flush();                    // accounts now have Ids
Id acctId = [SELECT Id FROM Account LIMIT 1].Id;  // or read it off the bundle
// ... now build children that reference acctId, still DEFERRED, flush again
```

▶ Runnable: `XFTY_Ex_Adv_DeepSetupChainsTest` _(pending — Pass B)_
