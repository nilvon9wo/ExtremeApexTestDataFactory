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
| `RELATED_ONLY` | Insert only the generated related records; leave the primary records uninserted. |
| `NOW` | Insert every generated record. |
| `LATER` | Behaves exactly like `NEVER`; documents that the caller will insert later. |
| `DEFERRED` | Generate like `NEVER`, but register every record so one `XFTY_DeferredInserter.flush()` inserts the whole set — see [deferred-insert](deferred-insert.md). |

The generated data is identical regardless of mode; only persistence changes.

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

## `RELATED_ONLY`

Inserts the generated parents but not the primary records — a test that needs
valid lookup targets but wants to insert the primaries itself. Internally XFTY
upgrades relationship generation to `NOW` while leaving the primaries untouched.

It only inserts a Provider's **ancestors**. Child collections
([`with` / `withChildren`](child-records.md)) are not ancestors, so under
`RELATED_ONLY` they are generated but not inserted.

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
| Needs inserted lookup targets only | `RELATED_ONLY` |
| Integration test | `NOW` |

Most tests start with `MOCK` + `REQUIRED` inclusivity — no DML, realistic Ids,
valid required data, compact graphs. Switching a test from unit to integration is
then a one-line change to `NOW`. See
[advanced/unit-vs-integration](advanced/unit-vs-integration.md).

▶ Runnable: `XFTY_Ex_InsertModesTest`

See also: [deferred-insert](deferred-insert.md) · [relationships](relationships.md) · [bundles](bundles.md)
