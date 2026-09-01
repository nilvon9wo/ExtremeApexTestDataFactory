# Roadmap: Descendant (Up-Flowing) Value Reads

Status: **✅ built** (option B). `XFTY_CopyFromDescendantExpression`, resolved in a pass over
the whole `DEFERRED` forest just before the depth-batched insert. This was
decision 4 of [context-aware-values.md](context-aware-values.md); usage in
[../use/context-aware-values.md](../use/context-aware-values.md#reading-up-from-a-child).

Implemented:

- `XFTY_DeferredExpressionIntf` — a value read up from a descendant; its own template
  slot (`deferredValueBySObjectFieldMap`), so the normal value passes ignore it.
- `XFTY_CopyFromDescendantExpression(childLookupField, sourceField)` — copy a field from the
  child that references this record through `childLookupField`; first matching
  child, or `null`.
- `XFTY_DummySObjectFactory` leaves the field unresolved and calls
  `bundle.deferValues(...)`; **in any mode but `DEFERRED` / `.depthBatched()` it
  throws** (the forest never exists otherwise) — not a silent `null`.
- `XFTY_DeferredInsertBuffer` captures each pending value keyed by the record's
  flat index; `XFTY_DescendantValuePass` (via `XFTY_DeferredGraph.childrenOf`)
  fills them at the top of `insertAll()` / `resolveAll()`, before the insert.
- Works for a generated ancestor reading its requesting child **and** for a
  parent reading one of its `withChildren` rows — the parent link is the same
  shape either way.

Not yet: a multi-hop path form (`XFTY_CopyFromAncestorExpression` has one); reading an
**aggregate** across many children (only the first is read); a loud error when a
`DEFERRED` build registers one but never calls `flush()` (the value stays `null`,
like the rest of that un-flushed graph).

---

## The need

[Context-aware values](../use/context-aware-values.md) read *down* the tree (from
a generated ancestor) and *sideways* (a sibling on the same record). Reading
*up* — a **parent** field derived from a generated **child** — cannot ride the
same pass, because the child does not exist when the parent is built.

Example: `Account.Site` set to match its generated primary `Contact.Department`,
so a validation rule comparing the two passes.

---

## Decision: build option B, skip option A

**Option B** — a value pass inside `DEFERRED` `flush()`.
[Deferred persistence](deferred-persistence.md) already accumulates the entire
forest in `XFTY_DeferredInsertBuffer` before it inserts. A pass over those
buffered records at the start of `flush()`, before the depth-batched insert, sees
every record — so an up-flowing expression can read any descendant.

**Option A** — a light `context.requestingChildTemplate` (the child's seed
template, available when the factory builds a parent because a child asked for
it). Covers only "a matching value the test set explicitly on the child", and
only for that one requesting child.

| | Option A | Option B |
|--|----------|----------|
| Works in | any insert mode | `DEFERRED` only |
| Covers | one requesting child's seed value | any descendant, fully generated |
| New machinery | small | a pass + a descendant-scoped context |
| Perf | free | one extra in-memory pass at `flush()`, `O(records × strategies)` — negligible beside the DML it precedes; skip it entirely when no up-flow expression is registered |

They are **not mutually exclusive** — A would serve non-`DEFERRED` tests while B
serves `DEFERRED` — but maintaining both doubles the surface for a feature B
already covers. So: **B only.**

### The constraint this imposes

Up-flowing reads require `DEFERRED` mode. A test that needs one and is not using
`DEFERRED` gets a clear error, not a silent `null`. Likewise a `DEFERRED` test
that registers an up-flow expression but never calls `flush()` — the value stays
unresolved, and reading it must fail loudly (same "not-computed vs computed-null"
distinction as the [sibling guard](../use/context-aware-values.md)).

No toggle is needed: B's cost is negligible and it self-skips when nothing
registers an up-flow expression.
