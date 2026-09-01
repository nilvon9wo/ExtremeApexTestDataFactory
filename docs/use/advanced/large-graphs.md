# Keeping Large Graphs Within Budget

When a test needs a lot of data, three levers keep it inside the governor limits
— leaving headroom for the code actually under test.

---

## 1. Generate less — inclusivity

Prefer [`REQUIRED`](../relationships.md#inclusivity) over `ALL`. Every optional
relationship can itself generate more relationships.

## 2. Stop the recursion — `PREVENT_CASCADE`

For deep or circular models, [`PREVENT_CASCADE`](../relationships.md#prevent_cascade)
generates the first level of relationships and no further.

## 3. Insert in fewer statements — `.depthBatched()`

One `NOW` call normally runs one `insert` per Provider. `.depthBatched()`
collapses that to one `insert` per dependency depth:

```apex
new XFTY_DummySObjectProvider(Case.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .depthBatched()
    .supplyBundle();
```

See [deferred-insert](../deferred-insert.md) for the trade-off (it changes
`insert` order — opt-in).

---

## XFTY tells you when you're close

After every `supply*()` call and every `XFTY_DeferredInserter.flush()`, XFTY
`System.debug(WARN)`s if generation alone consumed over half of any governor
limit. Watch the log for `XFTY:` lines.

## Measuring

The `XFTY_Load` suite (`test-support/`) pins where generation breaks each limit —
see [reference/volume-and-limits](../../reference/volume-and-limits.md) for the
observed ceilings (short version: ~1,000–1,500 primaries per `NOW` / `DEFERRED`
transaction, a few thousand for `MOCK`). Model your own volume assertions on it.

▶ Runnable: `XFTY_Ex_Adv_LargeGraphsTest`
