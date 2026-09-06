# Insert Modes

XFTY separates **generating** records from **inserting** them. Insert mode
controls what happens after generation; [inclusivity](relationships.md#inclusivity)
controls how much of the graph is generated. The two are independent.

```apex
.setInsertMode(XFTY_InsertModeEnum.MOCK)
```

---

## The modes

| Mode | Behaviour |
|------|-----------|
| `NEVER` | Generate records without Ids. |
| `MOCK` | Generate realistic Salesforce Ids **without DML**. |
| `NOW` | Insert every generated record. |
| `LATER` | Behaves exactly like `NEVER`; documents that the caller will insert later. |
| `DEFERRED` | Generate like `NEVER`, but register every record so one `XFTY_DeferredInserter.flush()` inserts the whole set — see [deferred-insert](deferred-insert.md). |

The generated data is identical regardless of mode; only persistence changes.
[`.excludePrimaryIds()`](#excluding-the-primary--excludeprimaryids) is a separate,
orthogonal setting — not a mode of its own — that composes with any of the five.

---

## `MOCK` — the unit-test default

```apex
Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .supply();

Assert.isNotNull(result.Id);
```

Realistic-looking Ids, no database. **Never perform DML on a `MOCK` record** —
those Ids do not point at real rows.

---

## `NOW` — the integration-test default

Inserts requested records, required related records, and (under `ALL`) optional
related records. Use for tests that touch the database.

---

## Excluding the primary — `.excludePrimaryIds()`

For a not-yet-inserted primary that must still relate to a **real, or
realistically Id'd, ancestor** — an Account that genuinely exists (or will), not a
placeholder Id nothing points at. `.excludePrimaryIds()` leaves this call's own
primary record(s) un-Id'd — no mock Id, no insert, no `DEFERRED` registration for
them specifically — while every ancestor they need is persisted exactly as the
configured insert mode already says. Ancestors are never affected, no matter how
deep the chain; only this call's own top-level output is excluded.
`.includePrimaryIds()` undoes it, back to the default.

It composes with any mode — each combination answers a different version of "how
real does the ancestor need to be":

**`NOW` + `.excludePrimaryIds()`** — the ancestor is genuinely inserted, one at a
time as it is generated (so real trigger order is preserved). This is the exact
behaviour the old `RELATED_ONLY` mode gave.

```apex
Contact result = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.NOW)
    .excludePrimaryIds()
    .supply();

Assert.areEqual(null, result.Id, 'the primary Contact is left uninserted');
Assert.isNotNull(result.AccountId, 'but it points at a real, inserted Account');
```

**`MOCK` + `.excludePrimaryIds()`** — the same shape, but the ancestor only gets a
**mock** Id; no DML at all.

**`DEFERRED` + `.excludePrimaryIds()`** — the capability no single mode could
express before: a primary with a deep ancestor tree (or several Providers' worth
of ancestors, across separate calls sharing one registry) built and flushed
together, depth-batched, while the primary that relates to it stays un-Id'd for
the whole lifetime of the call.

```apex
XFTY_DummySObjectBundle bundle = new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .setInsertMode(XFTY_InsertModeEnum.DEFERRED)
    .excludePrimaryIds()
    .supplyBundle();

XFTY_DeferredInserter.flush();
// bundle's Contact primary is still un-Id'd after the flush; its Account
// ancestor (and anything else registered before the flush) is really inserted
```

`NOW` inserts ancestors one at a time as each is generated — right when insert
order matters, but not batched. `.depthBatched()` (an explicit opt-in) or
`DEFERRED` batch the ancestor tree instead; the excluded primary is held back
either way.

It only ever affects a Provider's own **primary**. Child collections
([`with` / `withChildren`](child-records.md)) are not primaries of this call, so
`.excludePrimaryIds()` does not touch them — they are still persisted under
whatever mode they inherit or set, just with a `null` back-reference when the
parent they would point at was excluded.

### `.includePrimaryIds()`

Undoes `.excludePrimaryIds()` — the last call wins. Rarely needed explicitly
(it is already the default), but real for a helper deciding dynamically, or for
a caller who would rather spell the default out than lean on it silently.

---

## Child collections

A child collection ([`with` / `withChildren`](child-records.md)) inherits the
parent Provider's mode unless it sets its own. A child may raise or lower that
mode — parent `NEVER` + child `NOW` is common — with **one** exception: mixing
mock Ids with real DML in either direction (parent `MOCK` + child `NOW`, or
parent `NOW` + child `MOCK`) throws `XFTY_SObjectChildProvider.SanityException`.
Under `DEFERRED` / `.depthBatched()` a child's override is ignored entirely; the
whole subtree flushes together.

---

## Choosing

| Scenario | Mode |
|----------|------|
| Pure unit test | `MOCK` |
| Testing object construction only | `NEVER` |
| Test inserts the records itself | `LATER` |
| Data built over several calls, one insert phase | `DEFERRED` |
| Primary relates to a real, inserted ancestor, one at a time, but is not inserted itself | `NOW` + `.excludePrimaryIds()` |
| Same, but the ancestor only needs a valid-looking Id | `MOCK` + `.excludePrimaryIds()` |
| Same as the `NOW` row, but the ancestor tree is deep and wants batched insertion | `DEFERRED` + `.excludePrimaryIds()` |
| Integration test | `NOW` |

Most tests start with `MOCK` + `REQUIRED` inclusivity — no DML, realistic Ids,
valid required data, compact graphs. Switching a test from unit to integration is
then a one-line change to `NOW`. See
[advanced/unit-vs-integration](advanced/unit-vs-integration.md).

▶ Runnable: `XFTY_Ex_InsertModesTest`

See also: [deferred-insert](deferred-insert.md) · [relationships](relationships.md) · [bundles](bundles.md)
