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
- **ancestor read** - a field copied down from a generated parent / grandparent
  (`Contact.Department` = its `Account`'s `Site`);
- **generated-sibling-record read** - a value taken from another record generated
  in the same run.

All three are the same shape: *the strategy needs the generation context*.

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

**Up-flowing** values (an ancestor field that depends on a *descendant*) are out
of scope here - they need the deferred pass described in
[future-ideas.md - Dynamic Ancestor Configuration](../future-ideas.md#dynamic-ancestor-configuration).
This proposal is down-flowing and sideways only.

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

1. `XFTY_ContextAwareValueIntf`; `XFTY_GenerationContext.forRecord(sObj, ancestorBundle)`
   + the two nullable fields. No dispatch yet.
2. `XFTY_DummySObjectFactory`: split `cloneAndCompleteNonRelationshipValues` into
   the two passes; dispatch context-aware strategies in pass 2 with
   `context.forRecord(...)`.
3. `XFTY_CopyFromSibling`, `XFTY_CopyFromAncestor` + tests.
4. Docs: customization.md (a "context-aware values" section), internals.md (the
   two-pass detail), a worked `isOver18` example in `test-support/` if it needs a
   custom field.

---

## Open questions for review

1. **Decision 1** - go with **A** (extending interface, `instanceof` dispatch)?
2. **Decision 3** - ship the simple **two-pass** (A) and document the
   context-aware-reads-context-aware limitation, or invest in topological /
   lazy resolution now?
3. `XFTY_CopyFromAncestor` - is single-hop (`relationshipField, sourceField`)
   enough for v1, or is multi-hop path support needed from the start?
