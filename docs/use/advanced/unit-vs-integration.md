# Unit vs Integration Tests, One Set of Providers

XFTY's point: the *same* Provider definitions serve both isolated unit tests and
database integration tests. Only the [insert mode](../insert-modes.md) changes.

---

## The shared shape

```apex
private static final XFTY_DefaultSObjectProviderLookup lookup = new XFTY_DefaultSObjectProviderLookup();
```

A unit test:

```apex
Contact generatedContact = (Contact) new XFTY_DummySObjectProvider(Contact.SObjectType, lookup)
    .setInsertMode(XFTY_InsertModeEnum.MOCK)
    .setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
    .supply();
```

The integration test changes one line:

```apex
    .setInsertMode(XFTY_InsertModeEnum.NOW)
```

- `MOCK` + `REQUIRED` — no DML, realistic Ids, valid required data, compact
  graphs. The recommended starting point.
- `NOW` + `REQUIRED` — the same graph, actually inserted.

Because the data *description* does not change, a test can usually be promoted
from unit to integration (or the reverse) without touching its setup.

---

## What "usually" is carrying

The flip is free only when the graph can actually be inserted. Four things stop
that, and none of them are bugs XFTY can remove:

1. **A Provider is only as correct as its author kept it.** `MOCK` never runs
   validation rules, triggers, flows, duplicate rules or required-field checks;
   `NOW` runs all of them. A Provider that has drifted behind the org — a new
   required field, a new validation rule — passes every `MOCK` test and fails
   the moment the same test runs `NOW`. The fix belongs in
   [the Provider](../../extend/providers.md), not the test; the framework can
   centralise that fix but cannot guarantee it was made.

2. **Some SObjects cannot be inserted from Apex at all** — custom metadata
   types, most platform events, and various read-only standard objects. A graph
   that includes one works under `MOCK` and throws under `NOW`. Keep those tests
   `MOCK`-only.

3. **Mixed DML.** When the required graph spans **setup** objects (`User`,
   `Profile`, `PermissionSet`, `Group`, `Territory`, …) and ordinary objects,
   Salesforce forbids inserting both in one transaction. Under `MOCK` there is
   no DML so it never surfaces; under `NOW` it throws `MIXED_DML_OPERATION`.
   Insert the setup records in a `System.runAs` block (or a separate step)
   before the rest of the graph.

4. **Values the test forced in that a real `insert` cannot set.** A unit test
   can reach past the SObject API — the well-known `JSON.serialize` /
   `deserialize` round-trip (e.g. Nebula's `TestingUtils`) writes read-only
   fields, system fields (`CreatedDate`, `LastModifiedById`), formula and
   rollup-summary fields, or populates a parent relationship object or a child
   subquery in memory. Under `MOCK` those stick and the assertions pass. Under
   `NOW` the same fields come back to whatever a real `insert` (plus
   recalculation) produces — often `null` or a different value — and the test
   fails in the *opposite* direction from the cases above: the unit test is
   green, the integration test is red.

   `bundle.inject(field, config)` / `injectAll` and `XFTY_SObjectInjector`
   ([enrichment](../enrichment.md)) do exactly this, on purpose. **XFTY does not
   stop you running DML on an injected record — that is deliberate, not
   enforced — but it is at your own risk.** An injected record is fiction: it may
   carry a mocked `Id`, populated relationship objects, a *snapshot* child
   subquery, and read-only / formula / roll-up values a real `insert` would
   reject or recompute. Attempting DML against one typically **throws**
   (`INVALID_FIELD_FOR_INSERT_UPDATE` on the `Id`, *field is not
   writeable* on a formula, `MALFORMED_ID` / `ENTITY_IS_DELETED` on an update to
   a mocked `Id`); when it does *not* throw, you get a **false positive** — the
   assertion passes on a shape the database would never hold. Related traps: the
   deserialized instances are independent copies (mutating one end of a
   relationship does not update the other, and `contact.Account.Contacts[0]` is
   not `contact`), the subquery is a fixed snapshot (add a child, re-read it, and
   you still see the old list), and a `Blob` carried across the round-trip is
   lost if that record is serialized again downstream. Treat an injected graph as
   read-only input to a `MOCK` unit test and nothing else.

The takeaway: default to `MOCK`, and treat a `NOW` run as its own thing that has
to be *kept* green, not as a switch that is guaranteed to stay flipped.

▶ Runnable: `XFTY_Ex_Adv_UnitVsIntegrationTest`
