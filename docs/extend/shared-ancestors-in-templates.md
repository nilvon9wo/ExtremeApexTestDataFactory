# Shared Ancestors in a Master Template

A relationship slot normally holds an `XFTY_DummyDefaultRelationship`, which
generates a fresh parent per child. To make a relationship point at **one shared
record** instead, put an `XFTY_SharedAncestor` in the same slot:

```apex
new XFTY_DummySObjectMasterTemplate(Contact.Id)
    .putRequired(Contact.AccountId, XFTY_SharedAncestor.get('primary-account'));
```

`XFTY_SharedAncestor` implements the relationship interface, so `putRequired` /
`putOptional` accept it unchanged. Configure it once, centrally — the same way a
project defines its [flavoured lookup keys](provider-variants.md):

```apex
XFTY_SharedAncestor.get('primary-account').of(new Account(Name = 'Primary'));
```

### On-demand vs declared

The template reference (`XFTY_SharedAncestor.get('name')`) is the same for both
[kinds](../use/shared-ancestors.md#two-kinds). What differs is the central
config:

```apex
// on-demand - lightweight, resolves inline, no opt-in
XFTY_SharedAncestor.get('primary-account').of(new Account(Name = 'Primary'));

// declared - deep / heavy, resolves in a batched pre-phase, a test must require() it
XFTY_SharedAncestor.declared('root')
    .of(new MyHierarchyObj__c())
    .withKey(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));
```

A Provider whose Master Template references a **declared** ancestor only works in
a test that `XFTY_SharedAncestor.require(...)`s it — otherwise generation throws,
naming the ancestor. Reserve declared for a shared record that is itself a
hierarchy.

---

## When to put it in a *shipped* Provider

Only when the shared parent is genuinely part of the model — a singleton config
record, an org-wide root. For a test-specific "these all share one account", it
is clearer to set it on the `XFTY_DummySObjectProvider` instance in that test
with `.putRequired(...)`.

Full behaviour, configuration, and current limits:
[use/shared-ancestors](../use/shared-ancestors.md). Design and the deep-hierarchy
acceptance scenario: [roadmap/shared-ancestors](../roadmap/shared-ancestors.md).
