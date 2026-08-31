# Unit vs Integration Tests, One Set of Providers

XFTY's point: the *same* Provider definitions serve both isolated unit tests and
database integration tests. Only the [insert mode](../insert-modes.md) changes.

---

## The shared shape

```apex
private static final XFTY_DefaultSObjectProviderLookup LOOKUP = new XFTY_DefaultSObjectProviderLookup();
```

A unit test:

```apex
Contact c = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, LOOKUP)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
```

The integration test changes one line:

```apex
    .setInsertMode(XFTY_InsertModeEnum.NOW)
```

- `MOCK` + `REQUIRED` — no DML, realistic Ids, valid required data, compact
  graphs. The recommended starting point.
- `NOW` + `REQUIRED` — the same graph, actually inserted.

Because the data description does not change, a test can be promoted from unit to
integration (or the reverse) without touching its setup.

▶ Runnable: `XFTY_Ex_Adv_UnitVsIntegrationTest` _(pending — Pass B)_
