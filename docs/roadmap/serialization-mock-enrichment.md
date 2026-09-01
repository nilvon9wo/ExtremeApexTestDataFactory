# Roadmap: Serialization-Based Mock Enrichment

Status: **📋 proposed, not built.** Two related asks that both need the one
thing the SObject API cannot do in memory — write a field or relationship that
`record.put(...)` rejects — via a `JSON.serialize` / `deserialize` round-trip
(the technique in Nebula's `TestingUtils` / the `XAP_TEST_ReadOnlyHelper` the
project has floated).

Both are opt-in test conveniences for `MOCK` / `NEVER` graphs. Neither is core,
and the serialization cost is the reason they may stay proposed.

---

## Idea A — force read-only field values

A test wants a `MOCK` record to carry `CreatedDate`, a formula result, a
rollup, `IsClosed`, `LastModifiedById`, etc. `record.put(field, value)` throws
for these; the JSON round-trip works.

### Why this is a post-generation utility, not a value interface

- The round-trip **returns a new SObject instance**. XFTY's bundle model — and
  `DEFERRED` in particular — relies on the generated instances being the ones
  that get Ids back-filled and FKs wired. A value pass that reserialized
  mid-generation would sever every reference the engine holds.
- So it can only be a **terminal transform**: applied to the final records,
  after all generation and Id assignment (and, under `DEFERRED`, after
  `flush()`), re-pointing the bundle's lists to the new instances.
- A terminal transform cannot feed [context-aware values](../use/context-aware-values.md)
  — you cannot read a forced read-only value during generation. That is
  acceptable: a read-only value on an uninserted record is fiction anyway.

### Enforcing "tests only, never Providers"

Not in the type system — by **surface**. The affordance lives only on the
consumer builder (`XFTY_DummySObjectProvider`, e.g. a terminal
`.overrideReadOnly(Map<SObjectField, Object>)`) or as a standalone
`@IsTest` util (`XFTY_ForceValue.set(record, map)` / `set(List<SObject>, map)`).
It is **not** on `XFTY_DummySObjectMasterTemplate` or `XFTY_SObjectChildProvider`,
so a Provider has no way to emit a non-insertable record — the "Provider records
are always insertable" rule holds by construction.

Optional guard: throw if handed a record that already has a real Id (patching
read-only fields on a genuinely inserted row is meaningless).

### Cost

One serialize + deserialize per record. Opt-in and visible at the call site; a
batch form patches a whole list in one pass. Using it is itself the signal that
the test is `MOCK`-only — see
[unit-vs-integration.md](../use/advanced/unit-vs-integration.md) point 4.

---

## Idea B — populate parent relationship objects, not just the FK

Code under test that navigates `contact.Account.Owner.Name` needs the parent
*objects* on the record, which natively only a SOQL query provides — unavailable
to a true unit test. XFTY already **has** every parent in the bundle, 1:1
aligned; the transform is only to inject them where `put` cannot.

- For primary row `i`, for each relationship field, inject
  `bundle.getList(relField)[i]` under `relField.getDescribe().getRelationshipName()`
  (`AccountId` → `Account`, `WhatId` → `What`, `Foo__c` → `Foo__r`); recurse via
  `getBundle(relField)` for grandparents.
- Same instance-identity constraint as Idea A → terminal transform, `MOCK` /
  `NEVER` (or `DEFERRED` post-`flush()`).
- **Opt-in and path-scoped**, because the cost multiplies with depth × record
  count: `.withParentsPopulated()` (all generated relationships) or
  `.withParentsPopulated(List<List<SObjectField>> paths)` (only those paths).

This is the higher-value of the two — a lot of real code receives records and
reads through them. It does not help code that issues its own SOQL.

---

## If built, build them as one mechanism

Both are "JSON round-trip the final bundle to inject what `put` cannot." One
internal `XFTY_BundleSerializationPass` (terminal, re-points lists, refuses
real-Id records / non-`MOCK`-non-`NEVER` unless post-flush), two public entry
points. A shipped version needs tests around the JSON quirks — datetime
formatting, `Blob` fields, compound `Location` fields, the required
`attributes.type` on deserialize.

## Open questions

- Is Idea B common enough to justify the surface, or do most consumers navigate
  relationships rarely enough that "read it off the bundle" suffices?
- Should `.overrideReadOnly(...)` and `.withParentsPopulated(...)` be blocked
  (throw) under `NOW` / `RELATED_ONLY`, or just no-op with a warning?
- Does the terminal-transform restriction bite anyone who wants a forced
  read-only value visible to a context-aware value? (No use case yet.)
