# Known Issues

Defects and rough edges. This page is for **things that are wrong**, not for
undecided design — for plan status and open questions see
[../roadmap/README.md](../roadmap/README.md).

---

## Open — for triage

_None currently._

---

## Fixed (kept for context)

- A mismatched override-template list silently retargeted the Provider
  (`setOverrideTemplateList([new Account()])` on a `Contact` Provider quietly
  became an `Account` Provider). The constructor's type now wins and a
  different-typed list throws `ConflictException`.
- `ALL` inclusivity + a self-referential relationship recursed until the stack
  blew. `XFTY_AncestorCycleGuard` now throws a clear error on the second repeat
  of a Provider key up the ancestor chain; `.allowAncestorCycles()` suppresses
  it for a chain that terminates for another reason.

- Shipped tests required the Person Accounts feature — real-record-type
  assertions moved to `test-support/`.
- `profileIdFor` / `roleIdFor` returned `null` on a miss — now **throw**
  `XFTY_DefaultUserDataProvider.UnknownReferenceException`.
- `XFTY_DefaultSObjectProviderLookup.get()` swallowed the "unknown type" error —
  now throws.
- Provider-level `put(...)` / `removeFromMasterTemplate(...)` were no-ops — fixed.
- `XFTY_RecordTypeDataProvider` re-queried on every miss — now once per SObject.
- `XFTY_DummySObjectMasterTemplate` was shallow-cloned — added explicit `copy()`.
- `XFTY_InsertMocker` and `IndeterminateSObjectTypeException` — deleted (dead).
- A mis-ordered context-aware sibling read returned a silent `null` — now throws
  via `context.siblingValue(field)`.
- A shared ancestor resolved in `MOCK` then referenced from a `NOW` call used to
  drift a mock Id into real DML — now throws a clear "consistent insert mode"
  error (`XFTY_SharedAncestorTest.referencingAMockResolvedSharedAncestorFromANowCallThrows`).
- `bundle.getBundle(field)` returned null for a shared ancestor supplied via
  `XFTY_SharedAncestor.put(name, record)` (only `getList(field)` worked) —
  `getResolvedBundle()` now builds a single-record sub-bundle so the two stay
  consistent (`142c6d9`).
- An `XFTY_SharedAncestor` whose Provider reached back to the same name
  stack-overflowed — the pre-phase now detects the cycle (including across a
  re-entrant resolution) and throws, naming the ancestor.
- A shared ancestor could not be used with `.depthBatched()` / `DEFERRED` — it
  now resolves up front, honouring the call's real insert mode, so both work.
