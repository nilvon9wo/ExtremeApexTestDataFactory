# Known Issues

Defects and rough edges found while adding test coverage. Fixed items are kept
here for context; open items are for triage.

---

## Fixed

### `XFTY_DefaultSObjectProviderLookup.get()` swallowed the "unknown type" error
It constructed a `LookupException` but never threw it, so an unregistered
`SObjectType` fell through to a bare `NullPointerException`. Now throws.

### Provider-level `put(...)` was a no-op
`XFTY_DummySObjectProvider.supplyBundle()` branched on
`hasCustomMasterTemplate == null`, which is never true, so it always delegated to
the Provider's default template and ignored `put(...)` /
`removeFromMasterTemplate(...)` - both documented features. Fixed the branch and
`removeFromMasterTemplate()`'s missing flag assignment.

### `XFTY_RecordTypeDataProvider` re-queried on every miss
The cache was keyed by individual record type, so a lookup for a developer name
with no matching record type ran the SOQL again every call. Now tracks which
SObjects have been loaded and queries each at most once.

### Master template was shallow-cloned
Fixing the above exposed that `XFTY_DummySObjectMasterTemplate` was copied with
the implicit `clone()`, leaving the three field maps aliased to the Provider's
static template. Added an explicit `copy()` that recreates the maps.

---

## Open - for triage

### A single mismatched override template silently retargets the provider
`setOverrideTemplateList([new Account()])` on a
`new XFTY_DummySObjectProvider(Contact.SObjectType, ...)` sets
`this.sObjectType` from `list[0]` *before* the conflict check runs, so it
silently switches to `Account` instead of throwing. Only a **mixed-type list**
(`[new Contact(), new Account()]`) currently throws `ConflictException`.
Question: should an explicit constructor type always win?

### ~~`XFTY_InsertMocker` is dead code~~ (deleted)
Was a byte-for-byte earlier version of `XFTY_IdMocker`, referenced nowhere.
Removed on the `multi-variant-providers` branch.

### `ALL` inclusivity + a self-referential optional relationship recurses forever
e.g. an optional `Account.ParentId -> Account`. `PREVENT_CASCADE` is the current
workaround. Cycle detection in the engine would make `ALL` safe to use here.

### `XFTY_DummySObjectFactory.createBundle` always runs `insert insertSObjectList`
Harmless (an empty `insert` is a no-op) but unnecessary for `MOCK` / `NEVER` /
`LATER`.

### `XFTY_DefaultAccountDataProvider.createBundle` carries a Person Account scaffold
The commented-out record-type-selection block and its `masterTemplate == null`
guard are kept as a worked example of per-Provider template selection (the guard
is a documented defensive line). With `XFTY_RecordTypeLookupKey` this is no
longer the recommended approach - decide whether to wire it up as a real
Person/Business example or drop it.

### `IndeterminateSObjectTypeException` guards an unreachable state
`XFTY_DummySObjectProvider`'s constructor guarantees a non-null `SObjectType` and
nothing can clear it, so the two guards in the lazy getters cannot fire today.
Kept (with `IndeterminateSObjectTypeException`, which is public API) for a
possible future "construct now, set the type later" flow. Decide: keep, or drop
the guards and keep only the exception type.

### `XFTY_DefaultUserDataProvider` has an unfinished UserRole lookup
`createUserRoleIdByUserRoleNameMap` / `CEO_USERROLE_ID` are all `private` and
nothing consumes them - scaffolding for role-based test users that was never
finished. Kept for now (a `CEO` role in `test-support/` makes it run in CI).
Decide: finish the feature (expose role-based `TEST_*_USER` accessors) or remove.
