# Known Issues

Defects and rough edges found while adding test coverage. Fixed items are kept
here for context; open items are for triage.

---

## Fixed

### Shipped tests required the Person Accounts feature
`XFTY_RecordTypeMatchingTest` and `XFTY_LookupKeyTest` (in `force-app`, so part of
the package) resolved the built-in `PersonAccount` record type and NPE'd on
`getRecordTypeId()` in any org without Person Accounts. The real-record-type
assertions moved to `XFTY_RecordTypeRealRtTest` in `test-support/`; the
feature-independent paths stay in `force-app` and run anywhere.

### `profileIdFor` / `roleIdFor` returned null on a miss
Silent - a test that fed the null into `User.ProfileId` / `User.UserRoleId` hit an
opaque `INVALID_CROSS_REFERENCE_KEY` at insert instead of a clear error at the
call site. They now throw `XFTY_DefaultUserDataProvider.UnknownReferenceException`.

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

---

## Resolved on the branch

### ~~`XFTY_DummySObjectFactory.createBundle` always runs `insert insertSObjectList`~~
An empty `insert` is functionally a no-op but still spends a DML statement, and
`createBundle` recurses once per relationship level - so a `MOCK` generation of a
3-level graph burned 3 DML statements for nothing. Now guarded
(`if (!insertSObjectList.isEmpty())`). `XFTY_LoadTest` and
`XFTY_DummySObjectFactoryTest.mockAssignsIdsWithoutTouchingTheDatabase` assert
zero DML for `MOCK`.

### ~~`XFTY_DefaultAccountDataProvider.createBundle` carries a Person Account scaffold~~
The commented-out record-type-selection block and its `masterTemplate == null`
guard are gone. `XFTY_DefaultAccountDataProvider` is now a plain Business Account
Provider; the Person Account case is a real record-type variant -
`test-support/classes/XFTY_PersonAccountDataProvider` plus
`XFTY_PersonAccountVariantTest`, which run against a Person-Accounts-enabled
scratch org but are **not** in the published package.

### ~~`IndeterminateSObjectTypeException` guards an unreachable state~~
Verified unreachable and removed (class + both guards). `sObjectType` is set
non-null by the constructor and is only ever reassigned to another SObject's
never-null type; the class is not subclassable. If a "construct now, set the type
later" flow is ever added, reinstate it then.

### ~~`XFTY_DefaultUserDataProvider` has an unfinished UserRole lookup~~
Finished. The `private` CEO scaffolding is replaced by public cached lookups
`profileIdFor(name)` and `roleIdFor(developerName)`. Both **throw**
`XFTY_DefaultUserDataProvider.UnknownReferenceException` when the org has no such
Profile / UserRole - they are accessors, and a caller relying on the returned Id
should hear about a missing one at the call site, not via an opaque DML error
later. Their own tests self-provision a `UserRole` rather than depending on
org-specific metadata.
