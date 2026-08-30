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

## Decision 1 - how a strategy receives the context

Options:

| | Shape | Cost |
|-|-------|------|
| **A** *(recommended)* | New `XFTY_ContextAwareValueIntf extends XFTY_DummyDefaultValueIntf`, adding `Object get(XFTY_GenerationContext context)`. The factory dispatches on `instanceof`. | A context-aware strategy implements *both* `get()` and `get(context)`. Its `get()` throws a clear "needs a generation context" error (it is only reached if the strategy is used somewhere the engine has no context, which shouldn't happen). |
| **B** | `XFTY_ContextAwareValueIntf` as a *separate* interface (no `extends`). | `XFTY_DummySObjectMasterTemplate.defaultBySObjectFieldMap` can no longer be `Map<SObjectField, XFTY_DummyDefaultValueIntf>` - becomes `Map<SObjectField, Object>` or a wrapper. Looser typing everywhere. |
| **C** | Change `XFTY_DummyDefaultValueIntf.get()` to `get(XFTY_GenerationContext)`. | Every value strategy - the six bundled ones and every consumer's custom strategy - changes signature, most to ignore the argument. Big blast radius for little gain. |

**A** keeps the Master Template map typed, keeps all existing strategies working
untouched, and the dispatch is one `instanceof` where values are resolved:

```apex
Object value = (strategy instanceof XFTY_ContextAwareValueIntf)
        ? ((XFTY_ContextAwareValueIntf) strategy).get(context)
        : strategy.get();
```

---

## Decision 2 - what the context exposes to a value

`XFTY_GenerationContext` gains (nullable - populated only for the per-record
value pass, `null` for the top-level context):

- `SObject recordBeingBuilt` - the in-progress record, with every field filled so
  far;
- `XFTY_DummySObjectBundle ancestorBundle` - the bundle of records generated for
  *this* record's relationships, so a strategy can read
  `context.ancestorBundle.getList(Contact.AccountId)[0].Site`.

Derived the same way as `forRelated()`:

```apex
context.forRecord(sObjectInProgress, ancestorBundle)
```

Insert mode / Provider Lookup / inclusivity ride along unchanged.

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

Mechanically this is the same deferred pass
[future-ideas.md - Dynamic Ancestor Configuration](../future-ideas.md#dynamic-ancestor-configuration)
needs, and shares the phase-2/3 split. `XFTY_GenerationContext` would carry a
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
  - returns `ctx.ancestorBundle.getList(relationshipField)[rowIndex].get(sourceField)`.
  A deeper path (`Opportunity -> Account -> Owner.Name`) is a v2 concern - it needs
  the row index threaded and the sub-bundle walked.

Anything with actual logic (`isOver18`) is a three-line consumer
`XFTY_ContextAwareValueIntf` implementation - XFTY ships the plumbing, not a
mini-expression-language.

---

## Rough implementation plan

### Increment 1 - sibling + ancestor (done)

1. `XFTY_ContextAwareValueIntf extends XFTY_DummyDefaultValueIntf`;
   `XFTY_GenerationContext.forRecord(record, ancestorBundle, rowIndex)` + the
   nullable fields.
2. `XFTY_DummySObjectFactory`: `cloneAndCompletePlainValues` (pass 1, skips
   context-aware) + `completeContextAwareValues` (pass 2, after wiring).
3. `XFTY_CopyFromSibling`, `XFTY_CopyFromAncestor` (single hop) + tests.
4. Docs: customization.md section, internals.md two-pass detail.

### Increment 2 - descendant reads (decision 4)

Either `context.requestingChildTemplate` (light) or the full deferred up-flow
pass. Decide alongside the depth-batched-insert work.

### Later

Multi-hop `XFTY_CopyFromAncestor` path; topological / lazy sibling resolution if
the insertion-order limitation bites.

---

## Resolved decisions

- **1** - **A**: `XFTY_ContextAwareValueIntf extends XFTY_DummyDefaultValueIntf`,
  `instanceof` dispatch. Existing strategies untouched.
- **3** - two-pass, insertion order. Documented limitation: a context-aware value
  reading another only sees it if that one was `put(...)` first.
- `XFTY_CopyFromAncestor` ships single-hop; multi-hop is a later increment.

## Open

- **Decision 4** - `requestingChildTemplate` vs. full deferred pass for descendant
  reads.
