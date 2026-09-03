# Volume & Governor Limits

## Do you need this page?

**Almost certainly not for a normal test.** A typical test generates 1–20
records; a "bulk" test 100–200. Every ceiling below is in the **thousands**. You
would have to be deliberately building a large integration fixture, or something
seeding-shaped, to get close. If that is you, read on.

"Primary records" here means the records you asked for — one per
`setQuantityPerTemplate(n)`, `supplyList()` returns them. Each primary may pull
in a graph of generated parents, so *records generated* is usually a small
multiple of *primaries*.

---

XFTY generation runs inside your test's transaction and spends the same
per-transaction governor budget your code under test needs. This page says which
limits generation touches, how each scales, and roughly where it breaks.

**XFTY warns you automatically.** After every `supply*()` call (and every
`XFTY_DeferredInserter.flush()`), XFTY checks how much of each limit generation
consumed and `System.debug(LoggingLevel.WARN)`s when it crossed half — so a test
that is quietly eating the budget shows up in the debug log before it fails. The
warning names the limit and tells you to generate less.

**Tune or silence it** with the `XFTY_Settings__c` hierarchy custom setting
(read with `getInstance()` — no SOQL, org / profile / user scoped):

| Field | Effect |
|-------|--------|
| `LimitWarnSoftPercent__c` | warn past this % of a limit (default 50) |
| `LimitWarnHardPercent__c` | warn *harder* past this % (default 80) |
| `LimitWarningsDisabled__c` | turn the warning off entirely |

The numbers below were measured on a standard Developer Edition org with no
custom automation on `Account` / `Contact`. **Your org's triggers, flows,
validation rules, and sharing rules change them** — usually for the worse on
`NOW`. The `XFTY_Load` test suite (`test-support/`) is the living regression
guard; re-run it against your own org.

---

## How each limit scales

| Limit | Synchronous ceiling | How XFTY generation uses it |
|-------|--------------------|-----------------------------|
| **DML statements** | 150 | One `insert` per Provider (i.e. per SObject type) in the graph. `.depthBatched()` / `DEFERRED` collapse it to one per dependency *depth*. Independent of row count. |
| **DML rows** | 10,000 | One row per generated record. A Contact + its Account = 2 rows per primary. |
| **SOQL queries** | 100 | A small constant — the admin-user bootstrap, and at most one record-type query for the whole transaction. Does **not** grow with volume. |
| **SOQL query rows** | 50,000 | Same — a small constant. |
| **CPU time** | 10,000 ms | Grows with record count **and** graph depth/width. On `NOW`, the `insert`s (and their triggers) dominate. |
| **Heap** | 6 MB (sync) | Grows with the number of records held in memory — the whole bundle, kept until the test method ends. |

---

## Observed ceilings (standard org, quiet)

| Scenario | Result |
|----------|--------|
| `MOCK`, 5-level chain × 100 primaries (600 records) | well under every limit — MOCK does no DML |
| `NEVER`, 5,000 primaries + a parent each, held in memory | under the 6 MB heap limit |
| `NOW`, 3,000 primaries + a parent each (6,000 DML rows) | passes; ~50 s wall time (trigger-bound), CPU under budget |
| `NOW` + `.depthBatched()`, 15 parents → 150 children → 300 grandchildren (465 records, 3 levels) | ≤ 8 DML statements — downward fan-out multiplies *rows*, not *statements*; CPU well under budget |
| `MOCK`, 3,000 primaries with two context-aware value expressions each (sibling copy + custom `XFTY_ContextAwareExpressionIntf`) | 0 DML; CPU well under budget — the value pass stays cheap at volume |
| `NOW`, 500 children under **one shared ancestor** | 1 Account row, ≤ 4 DML statements — the shared record does not multiply |
| `NOW`, 12 **independent** shared ancestors, 10 children each | ≤ 24 DML statements, CPU well under budget — but see the note below |
| `NOW`, a **10-level** all-shared chain, 5 leaves | 10 Account rows, ≤ 12 DML statements — the chain depth-batches, one `insert` per level |
| `DEFERRED`, 2,000 primaries + parents (4,000 records), then `flush()` | `flush()` alone ≈ **5 s CPU — half the limit** |
| **`injectAll`**, 1,000 target records × 1 ancestor level (+ its inverse child) | 0 DML; CPU under budget — one round-trip per position, not per record |
| **`injectAll`**, 200 target records × a 5-deep ancestor chain (User at each level) | passes with headroom |
| **`injectAllChildren`**, 50 parents × 15 children each (~2k-record subtree) | passes with headroom |
| **`injectAll` both directions**, 250 parents × 15 children | passes with headroom |
| **`inject` + `childDepth(2).breakSoqlLimits()`**, nested grandchildren | works — the two-level subquery survives the round-trip on a real org |
| **`XFTY_SObjectInjector`**, 3,000 rows, one parent graft each | one serialize + one deserialize; CPU under budget |

**Practical ceilings for one transaction:**

- **`MOCK` / `NEVER`**: a few thousand primaries. Heap is the first wall (~5,000–6,000 primaries with a parent each).
- **`NOW` / `DEFERRED`**: **~1,000–1,500 primaries with parents.** The inserts and their triggers eat CPU fast; 4,000 records is already half the CPU budget before your code under test runs.
- **DML rows**: hard cap at 10,000 — so ~5,000 primaries for a 2-level graph, fewer for a deeper one.

### Shared ancestors

A shared ancestor's sub-graph is resolved **once** and inserted **depth-batched**
(one `insert` per dependency level), however many children reference it — a wide
fan-out (500 Contacts, one HQ) is one Account `insert`, and a deep all-shared
chain (`Root ← L1 ← … ← L9`) is one `insert` per level, not per record.

The one cost that does *not* collapse: resolution is a separate depth-batched
pass **per shared-ancestor sub-graph**, so *N independent heavy* shared ancestors
cost ~N extra `insert` statements up front (converging chains share theirs). If a
test registers many heavy shared ancestors it does not need — e.g. from
[packaged defaults](../use/shared-ancestors.md#packaged-defaults) —
`XFTY_SharedAncestor.manualResolutionOnly()` plus `disable(name)` /
`resolveNow(lookup, mode, names)` keeps only the ones it uses.

### Deep vs. wide

Both cost, and they multiply. A record's **depth** (its chain of ancestors) sets
how many `insert` *statements* / dependency layers it needs; its **width** (how
many parent types at each level) adds records and CPU per primary. A graph that
is 5 deep and 3 wide at each level is ~15 generated records per primary — so the
row and CPU ceilings above divide by roughly that. `PREVENT_CASCADE` (one level)
and tighter inclusivity are the levers.

### Serialization enrichment

[`inject` / `injectAll`](../use/enrichment.md) costs one `JSON.serialize` +
`JSON.deserialize` **per graph position visited**, over the whole list at that
position — not per record. So a wide-but-shallow graph is cheap regardless of
width; cost climbs with **depth** (`parentDepth`, `childDepth`) and with the
**total payload size** (records × fields serialized). It does no DML.

`injectAll` / `everything()` visits the most positions — every ancestor with its
inverse child, every downward child with its own ancestors — so it is the
expensive mode. A tight `inject(field, config)` naming only what a test needs is
much cheaper. The pass is wrapped in `XFTY_GovernorBudget`, which
`System.debug(WARN)`s when it has eaten a large share of CPU or heap. The
`XFTY_Load` suite (`XFTY_EnrichmentLoadTest`) exercises the shapes in the table
above; a few thousand records total across all visited positions is comfortable.

### Org seeding

[`XFTY_Seeder.seed(bundle)`](../use/org-seeding.md) runs real DML in **one
transaction**, so the same ceilings as a `NOW` generation apply — the DML-row cap
(10,000) first, then trigger-bound CPU. Roughly **~1,000–1,500 primaries with a
parent each** per `@IntegrationTest` method; split a bigger seed across several
methods. (The Bulk API path that would lift this is not built.)

---

## Keeping generation cheap

- Prefer **`MOCK`** for unit tests — it spends no DML and little CPU.
- Use **`REQUIRED`** inclusivity, not `ALL`; use **`PREVENT_CASCADE`** for deep or circular models.
- Generate the **minimum row count** the test needs. `setQuantityPerTemplate(5)` is usually plenty.
- For a shared parent across many children, use a
  [shared ancestor](../use/shared-ancestors.md) — it costs one insert, not one per child.
- If a `NOW` test needs thousands of rows, split the setup across `@IsTest`
  helper methods and (with care) `Test.startTest()` boundaries, or reconsider
  whether it should be an integration test at all.
- Watch the debug log for the `XFTY:` WARN lines — they are the early signal.
