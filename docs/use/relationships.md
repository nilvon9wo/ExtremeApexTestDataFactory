# Relationships

XFTY generates complete object graphs, not isolated records. A Provider describes
the relationships an `SObject` has, and XFTY creates the related records
automatically when a test asks for them.

- **This page:** required vs optional relationships, inclusivity, cascading.
- [per-call-relationships](per-call-relationships.md): one-off exceptions
  (`includeOptional`, `excludeRelationship`).
- [shared-ancestors](shared-ancestors.md): many children under one parent.
- [bundles](bundles.md): reading the generated graph.
- Writing the relationship into a Provider is an *extend* task —
  [extend/providers.md](../extend/providers.md).

---

## Required vs optional

A relationship is defined with `XFTY_DummyDefaultRelationship` and placed in
either the **required** or the **optional** slot of the Master Template.

```apex
.putRequired(Contact.AccountId, new XFTY_DummyDefaultRelationship(new Account()))
.putOptional(Contact.OwnerId,   new XFTY_DummyDefaultRelationship(new User()))
```

The supplied `SObject` acts as an override template for the generated parent —
its remaining fields come from that parent's own Provider. (This is why a
relationship takes an `SObject`, not an `SObjectType`.)

- **Required** relationships are generated whenever relationship generation
  includes required data. Use this only for relationships genuinely needed for
  valid test data.
- **Optional** relationships are generated only under `ALL` inclusivity. Prefer
  optional — every required relationship enlarges every generated graph.

Picking a Provider variant for the parent (record types, flavours) —
[provider-variants](provider-variants.md).

---

## Inclusivity

Relationship generation is controlled independently of insertion, with one
setting per call:

| Mode | Behaviour |
|------|-----------|
| `NONE` | Generate no related records — every relationship is the test's responsibility. |
| `REQUIRED` | Generate only required relationships. **The recommended default.** |
| `ALL` | Generate required **and** optional relationships. Richer graphs; use sparingly. |
| `PREVENT_CASCADE` | Generate the first level of relationships, but stop each generated parent from generating its own. |

```apex
.setInclusivity(XFTY_InsertInclusivityEnum.REQUIRED)
```

---

## Cascading

Relationship generation is recursive. An `OpportunityLineItem` that requires an
`Opportunity`, which requires an `Account`, generates all three:

```text
OpportunityLineItem
└── Opportunity
    └── Account
```

Each Provider is responsible only for its own type; together they produce the
whole graph.

### `PREVENT_CASCADE`

Some models are circular — an `Account` with a primary `Contact` that has an
`Account`. `PREVENT_CASCADE` lets the first Provider create its direct
relationships while every subsequently invoked Provider behaves as though
inclusivity were `NONE`:

```text
Account
└── Contact          (not Contact → Account → Contact → …)
```

Reducing graph size is a side effect; **stopping recursion is the point.**

### Self-referential relationships

`ALL` + a self-referential relationship (e.g. `Account.ParentId → Account`) would
recurse forever. XFTY generates **one level** and then throws a clear "cycle"
error if the same Provider would be generated again further up the graph. Options
for a genuine chain:

- **`PREVENT_CASCADE`** — exactly one level, no recursion.
- **distinct per-level Providers** (different [lookup keys](provider-variants.md))
  — each level is a different Provider, so it is not a cycle and recurses freely.
- **`.allowAncestorCycles()`** on the Provider — suppresses the guard when the
  chain terminates for another reason (or the guard is a false positive). You
  own the "does it terminate?" question.

---

## Performance

Every additional relationship increases object count, heap, DML, and trigger /
Flow execution. Prefer `REQUIRED` over `ALL`; keep required relationships
minimal; use `PREVENT_CASCADE` for deep or circular trees; use `NONE` only when
the test wants total control. For large graphs, see
[advanced/large-graphs](advanced/large-graphs.md).

▶ Runnable: `XFTY_Ex_RelationshipsTest`
