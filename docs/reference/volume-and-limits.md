# Volume & Governor Limits

XFTY generation runs inside your test's transaction and spends the same
per-transaction governor budget your code under test needs. This page says which
limits generation touches, how each scales with volume, and roughly where it
breaks.

**XFTY warns you automatically.** After every `supply*()` call (and every
`XFTY_DeferredInserter.flush()`), XFTY checks how much of each limit generation
consumed and `System.debug(LoggingLevel.WARN)`s when it crossed half — so a test
that is quietly eating the budget shows up in the debug log before it fails. The
warning names the limit and tells you to generate less.

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
| `NOW`, 500 children under **one shared ancestor** | 1 Account row, ≤ 4 DML statements — the shared record does not multiply |
| `DEFERRED`, 2,000 primaries + parents (4,000 records), then `flush()` | `flush()` alone ≈ **5 s CPU — half the limit** |

**Practical ceilings for one transaction:**

- **`MOCK` / `NEVER`**: a few thousand primaries. Heap is the first wall (~5,000–6,000 primaries with a parent each).
- **`NOW` / `DEFERRED`**: **~1,000–1,500 primaries with parents.** The inserts and their triggers eat CPU fast; 4,000 records is already half the CPU budget before your code under test runs.
- **DML rows**: hard cap at 10,000 — so ~5,000 primaries for a 2-level graph, fewer for a deeper one.

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
