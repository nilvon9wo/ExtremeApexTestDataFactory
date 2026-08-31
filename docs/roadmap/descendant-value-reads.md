# Roadmap: Descendant (Up-Flowing) Value Reads

Status: **📋 designed, not built.** Approach decided — see below. This is
decision 4 of [context-aware-values.md](context-aware-values.md).

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
every record — so an up-flowing strategy can read any descendant.

**Option A** — a light `context.requestingChildTemplate` (the child's seed
template, available when the factory builds a parent because a child asked for
it). Covers only "a matching value the test set explicitly on the child", and
only for that one requesting child.

| | Option A | Option B |
|--|----------|----------|
| Works in | any insert mode | `DEFERRED` only |
| Covers | one requesting child's seed value | any descendant, fully generated |
| New machinery | small | a pass + a descendant-scoped context |
| Perf | free | one extra in-memory pass at `flush()`, `O(records × strategies)` — negligible beside the DML it precedes; skip it entirely when no up-flow strategy is registered |

They are **not mutually exclusive** — A would serve non-`DEFERRED` tests while B
serves `DEFERRED` — but maintaining both doubles the surface for a feature B
already covers. So: **B only.**

### The constraint this imposes

Up-flowing reads require `DEFERRED` mode. A test that needs one and is not using
`DEFERRED` gets a clear error, not a silent `null`. Likewise a `DEFERRED` test
that registers an up-flow strategy but never calls `flush()` — the value stays
unresolved, and reading it must fail loudly (same "not-computed vs computed-null"
distinction as the [sibling guard](../use/context-aware-values.md)).

No toggle is needed: B's cost is negligible and it self-skips when nothing
registers an up-flow strategy.
