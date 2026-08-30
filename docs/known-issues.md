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

### `XFTY_DefaultAccountDataProvider.createBundle` carries dead record-type logic
The commented-out Person Account branch leaves a `masterTemplate == null` check
that can never be true. Either wire up record-type selection or remove the
scaffold.
