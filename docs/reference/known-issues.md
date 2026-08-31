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

### `bundle.getBundle(field)` is null after `XFTY_SharedAncestor.put(name, record)`

When a shared ancestor is **generated**, both `getList(field)` and
`getBundle(field)` are populated (`XFTY_SharedAncestorTest.theSharedRecordAppearsInBothTheListAndTheSubBundle`).
When the test supplies the record itself with `XFTY_SharedAncestor.put(name,
record)`, no sub-bundle is built, so `getBundle(field)` returns null while
`getList(field)` works — an inconsistency a consumer would not expect.

**Fix:** `XFTY_SharedRelationshipWiring` should place a single-record sub-bundle
for the field in the `put(...)` case too, so `getBundle(field)` is never null for
a wired shared ancestor. Longer term, `getList` / `getBundle` should share a
source so they cannot diverge for any relationship.

### `ALL` inclusivity + a self-referential relationship recurses until the stack blows

e.g. an optional `Account.ParentId → Account` under `ALL`. `PREVENT_CASCADE` is
the current workaround. This needs cycle detection in the engine — see
[../roadmap/README.md](../roadmap/README.md#open-questions) for the one open
question about how it should behave when it fires.

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
