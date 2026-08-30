# Design: Context-Aware Value Generation

Status: **proposal**. Builds directly on `XFTY_GenerationContext`
([internals.md - The Generation Context](../internals.md#the-generation-context)).

---

## The need

A value strategy today implements `XFTY_DummyDefaultValueIntf.get()` - no
arguments, no knowledge of anything around it. Real data models routinely need
more:

- **sibling read** - a field derived from another field on the *same* record
  (`isOver18 = age >= 18`; `AccountName` copied to a text field a validation rule
  compares);
- **ancestor read** *(down-flowing)* - a field copied down from a generated
  parent / grandparent (`Contact.Department` = its `Account`'s `Site`);
- **descendant read** *(up-flowing)* - a field on a parent copied *up* from a
  child (`Account.Site` set to match its generated `Contact`'s `Department`;
  a parent field a validation rule compares against a child's). This keeps
  matching values defined once, on whichever record the test naturally sets them.

All are the same shape - *the strategy needs the generation context* - but they
differ in **timing**:

| | When the other record exists |
|-|------------------------------|
| sibling | same record, ordering within one value pass (decision 3) |
| ancestor | already built - the factory builds relationships *before* the record's own values, so a parent is complete when its child's context-aware pass runs |
| descendant | **not yet built** when the parent's value pass runs - needs a deferred pass (decision 4) |

---

## Decision 1 - how a strategy receives the context — *resolved: B*

**`XFTY_ContextAwareValueIntf` is a separate interface** (one method,
`Object get(XFTY_GenerationContext context)`), *not* a subtype of
`XFTY_DummyDefaultValueIntf`.

Rejected **A** (extend `XFTY_DummyDefaultValueIntf`, no-arg `get()` throws): that
is a Liskov violation - a context-aware value handed to code expecting a plain
one blows up. Rejected **C** (change `XFTY_DummyDefaultValueIntf.get()` itself):
breaks every existing strategy for no gain.

The Master Template keeps its typed `defaultBySObjectFieldMap` and gains a second
typed map, `contextAwareBySObjectFieldMap`. `put(field, someObject)` routes:
context-aware -> its map; plain value -> its map; relationship -> rejected;
anything else -> exact literal. `orderedValueFields()` covers both maps in `put`
order.

---

## Decision 2 - what the context exposes to a value

`XFTY_GenerationContext` gains (nullable - populated only for the per-record
value pass, `null` for the top-level context):

- `SObject recordBeingBuilt` - the in-progress record, with every field filled so
  far;
- `XFTY_DummySObjectBundle bundleSoFar` - the bundle produced by the current
  `createBundle` call so far. It holds this record's generated relationships
  (`getList(Contact.AccountId)[0].Site`) **and** the sibling primary records
  (`getList(<primaryTargetField>)`) - the whole graph this call has built up to
  now;
- `Integer rowIndex` - which row of a multi-record generation this is (the index
  into every list in the bundle).

Derived the same way as `forRelated()`:

```apex
context.forRecord(sObjectInProgress, bundleSoFar, rowIndex)
```

Insert mode / Provider Lookup / inclusivity ride along unchanged.

### Later: the graph *across* calls, with a position pointer

`bundleSoFar` is scoped to one `createBundle` call. A value being generated for
a nested relationship (say the `Account` built for a `Contact`) does not see the
`Contact` in progress or anything above it. Threading a **root bundle** (or a
"graph so far" reference) plus a **path pointer** down through `forRelated()`
would give a strategy the full picture - every record generated or in progress in
this whole `supply*()` call, and where the current record sits in it. That is the
same plumbing the deferred whole-graph pass (decision 4) needs; do it there.

---

## Decision 3 - sibling ordering

`isOver18` must be evaluated *after* `age`. `cloneAndCompleteNonRelationshipValues`
currently fills fields in one loop over the template map, whose iteration order is
not something to rely on.

| | Approach | Handles |
|-|----------|---------|
| **A** *(recommended for v1)* | **Two passes.** Pass 1 fills every non-context-aware value. Pass 2 evaluates context-aware values, in template-insertion order, against a `recordBeingBuilt` that already has all the plain values (and any earlier context-aware ones). | sibling reads of plain fields; ancestor reads; context-aware reading an *earlier* context-aware sibling. |
| **B** | Each context-aware strategy declares the sibling fields it reads; topological sort. | arbitrary context-aware dependency chains. |
| **C** | `context.sibling(field)` resolves that field lazily on demand, recursing, with cycle detection. | everything, including cycles (as errors). |

**A** covers the motivating cases and is a small change. Document the limitation:
a context-aware value that reads *another* context-aware value only works if the
dependency was `put(...)` first. Revisit **B**/**C** if that bites.

Ancestor reads are unaffected by ordering - the ancestor bundle is fully built
before any of this record's values are filled (factory phase order), so pass 2
always sees complete ancestors.

---

## Decision 4 - descendant (up-flowing) reads

A parent field that copies *up* from a generated child can't be evaluated when
the parent is built, because the child does not exist yet. It needs a **deferred
pass over the whole graph**:

1. build the entire structure (every record, every relationship) with plain +
   sibling + ancestor values, no insert;
2. **up-flow pass** - walk the graph and evaluate descendant-reading strategies,
   now that every record exists in memory. Bottom-up isn't required; a single
   pass works because every record is present;
3. wire lookups, assign / insert Ids.

Mechanically this is the same deferred whole-graph pass that
[shared ancestors](shared-ancestors.md) needs (build in memory, evaluate, then
wire + insert per depth). `XFTY_GenerationContext` would carry a
`descendantBundle` (the records generated *from* this record's relationships,
i.e. the sub-bundle) for the up-flow pass to read.

A lighter partial answer that needs no deferred pass: when the factory builds a
parent *because* a child requires it, it already holds the child's
template + overrides - it could expose those (not the fully-generated child, just
the seed) as `context.requestingChildTemplate`. That covers "matching value the
test explicitly sets on the child" without restructuring the engine. Worth doing
first if the full deferred pass proves expensive.

**Increment plan:** ship sibling + ancestor now (no engine restructure). Add
descendant reads as the second increment - either the light `requestingChildTemplate`
or the full deferred pass, decided when the depth-batched-insert / dynamic-ancestor
work lands, since they share the machinery.

---

## Built-ins to ship

- `XFTY_CopyFromSibling(SObjectField field)` - `get(ctx)` returns
  `ctx.recordBeingBuilt.get(field)`.
- `XFTY_CopyFromAncestor(SObjectField relationshipField, SObjectField sourceField)`
  - returns `ctx.bundleSoFar.getList(relationshipField)[rowIndex].get(sourceField)`.
  A deeper path (`Opportunity -> Account -> Owner.Name`) is a v2 concern - it needs
  the row index threaded and the sub-bundle walked.

Anything with actual logic (`isOver18`) is a three-line consumer
`XFTY_ContextAwareValueIntf` implementation - XFTY ships the plumbing, not a
mini-expression-language.

---

## Rough implementation plan

### Increment 1 - sibling + ancestor (done)

1. `XFTY_ContextAwareValueIntf` (separate interface, decision 1: B);
   `XFTY_DummySObjectMasterTemplate.contextAwareBySObjectFieldMap` + a routing
   `put(field, Object)`; `XFTY_GenerationContext.forRecord(record, bundleSoFar,
   rowIndex)`.
2. `XFTY_DummySObjectFactory`: `cloneAndCompletePlainValues` (pass 1, plain map)
   + `completeContextAwareValues` (pass 2, context-aware map, after wiring).
3. `XFTY_CopyFromSibling`, `XFTY_CopyFromAncestor` (single + multi-hop) + tests.
4. Docs: customization.md section, internals.md value-passes detail.

### Increment 2 - descendant reads (decision 4)

Either `context.requestingChildTemplate` (light) or the `DEFERRED` insert mode
([deferred-persistence.md](deferred-persistence.md)). Decide alongside that work.

### Later

Topological / lazy sibling resolution if the insertion-order limitation bites
(decision 3 - do the lazy `context.sibling(field)` if it fits governor limits).

---

## Resolved decisions

- **1** - **B**: `XFTY_ContextAwareValueIntf` is a separate interface, second map
  on the Master Template. No LSP violation, no throwing no-arg `get()`.
- **3** - two-pass, insertion order, shipped. Also worth doing lazy
  `context.sibling(field)` (option C) later; only option B (declared deps +
  topological sort) is rejected as hard to consume.
- `XFTY_CopyFromAncestor` ships single- and multi-hop.

## Open

- **Decision 4** - `requestingChildTemplate` vs. `DEFERRED` mode for descendant
  reads.
