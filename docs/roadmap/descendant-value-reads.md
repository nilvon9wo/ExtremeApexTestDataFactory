# Roadmap: Descendant (Up-Flowing) Value Reads

Status: **📋 proposed**. This is decision 4 of
[context-aware-values.md](context-aware-values.md), spun out here because it is
the one context-aware direction still unbuilt.

---

## The need

[Context-aware values](../use/context-aware-values.md) currently read *down* the
tree (a field copied from a generated ancestor — `XFTY_CopyFromAncestor`) and
*sideways* (a sibling field on the same record — `XFTY_CopyFromSibling`). Reading
*up* — a **parent** field derived from a generated **child** — cannot ride the
same pass, because the child does not exist yet when the parent is built.

Example: `Account.Site` set to match its generated primary `Contact.Department`,
so a validation rule comparing the two passes.

---

## Two options

### A. Light — `context.requestingChildTemplate`

When the factory builds a parent *because* a child required it, it already holds
the child's seed template + overrides. Expose that (not the fully generated
child, just the seed) as `context.requestingChildTemplate`. Covers "a matching
value the test set explicitly on the child" with no engine restructure.

### B. Full — a value pass inside `DEFERRED` `flush()`

[Deferred persistence](deferred-persistence.md) already holds the whole graph in
memory between `supply*()` and `flush()`. A value pass that runs in `flush()`,
before the insert, sees every record — so an up-flowing strategy can read any
descendant. This is the same machinery
[declared shared ancestors](shared-ancestors.md) want.

---

## Open question

Ship **A** first (cheap, covers the common case) and add **B** when the
`DEFERRED` work merges, or wait and do **B** only? Decide alongside the
`deferred-persistence` merge.
