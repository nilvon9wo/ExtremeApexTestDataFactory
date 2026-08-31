# Known Issues

Defects and rough edges. This page is for **things that are wrong**, not for
undecided design — for plan status and open questions see
[../roadmap/README.md](../roadmap/README.md).

---

## Bugs to fix

### A mismatched override-template list silently retargets the Provider

`setOverrideTemplateList([new Account()])` on a
`new XFTY_DummySObjectProvider(Contact.SObjectType, ...)` runs
`this.sObjectType = list[0].getSObjectType()` before any conflict check, so it
silently switches to `Account`. Only a **mixed-type list**
(`[new Contact(), new Account()]`) currently throws.

**Decided fix:** an explicit `SObjectType` (or lookup-key) constructor argument
always wins, **and** a list whose entries are a different type throws
`ConflictException`. The two are not alternatives — do both. The shorthand
`new XFTY_DummySObjectProvider(List<SObject>, lookup)` constructor still derives
its type from the list (there was no explicit type to defend).

### `ALL` inclusivity + a self-referential relationship recurses until the stack blows

e.g. an optional `Account.ParentId → Account` under `ALL`. `PREVENT_CASCADE` is
the current workaround. The fix (ancestor cycle detection that throws, with an
off-switch) is a decided
[roadmap item](../roadmap/README.md#remaining-work-decided-needs-building).

---

## Fixed (kept for context)

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
