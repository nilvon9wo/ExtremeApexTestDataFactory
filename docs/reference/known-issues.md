# Known Issues

Open defects and rough edges. For plan status (built / in progress / proposed)
see [../roadmap/README.md](../roadmap/README.md).

---

## Open — for triage

### A single mismatched override template silently retargets the Provider

`setOverrideTemplateList([new Account()])` on a
`new XFTY_DummySObjectProvider(Contact.SObjectType, ...)` runs
`this.sObjectType = list[0].getSObjectType()` **before** the conflict check, so it
silently switches to `Account`. Only a **mixed-type list**
(`[new Contact(), new Account()]`) currently throws `ConflictException`.
Question: should an explicit constructor type always win, or should any
type change from a list be a `ConflictException`?

### `ALL` inclusivity + a self-referential optional relationship recurses until the stack blows

e.g. an optional `Account.ParentId → Account`. `PREVENT_CASCADE` is the current
workaround. Cycle detection in the engine would make `ALL` safe here.

### Shared ancestors — two invariants not yet kept

Tracked with the on-demand implementation
([../roadmap/shared-ancestors.md](../roadmap/shared-ancestors.md)):

- **Mixed insert modes drift the Id.** First resolved in `MOCK`, then referenced
  from a `NOW` call → children wired to a mock Id, `insert` fails.
- **`bundle.getBundle(field)` returns null** for a shared-ancestor field (only
  `getList(field)` works).

---

## Fixed (kept for context)

- Shipped tests required the Person Accounts feature — the real-record-type
  assertions moved to `test-support/`.
- `profileIdFor` / `roleIdFor` returned `null` on a miss — now **throw**
  `XFTY_DefaultUserDataProvider.UnknownReferenceException`.
- `XFTY_DefaultSObjectProviderLookup.get()` swallowed the "unknown type" error —
  now throws.
- Provider-level `put(...)` / `removeFromMasterTemplate(...)` were no-ops (a
  branch on `hasCustomMasterTemplate == null`, never true) — fixed.
- `XFTY_RecordTypeDataProvider` re-queried on every miss — now queries each
  SObject at most once.
- `XFTY_DummySObjectMasterTemplate` was shallow-cloned, aliasing the Provider's
  static maps — added an explicit `copy()`.
- `XFTY_InsertMocker` (a byte-for-byte duplicate of `XFTY_IdMocker`) and
  `IndeterminateSObjectTypeException` (guarded an unreachable state) — deleted.
- A mis-ordered context-aware sibling read returned a silent `null` — now throws
  a clear error via `context.siblingValue(field)`.
