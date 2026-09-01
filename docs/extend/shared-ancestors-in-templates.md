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
XFTY_SharedAncestor.put('primary-account', new Account(Name = 'Primary'));
```

### Flat vs deep — nothing to opt into

The template reference (`XFTY_SharedAncestor.get('name')`) and the central config
are the same however heavy the shared record is:

```apex
// flat - a plain parent; resolves as a single shared record
XFTY_SharedAncestor.put('primary-account', new Account(Name = 'Primary'));

// deep - a record that pulls in ancestors of its own; resolves as a
// depth-batched sub-graph, built once
XFTY_SharedAncestor.put('root', new MyHierarchyObj__c())
    .fromVariant(XFTY_RecordTypeLookupKey.get(MyHierarchyObj__c.SObjectType, 'Root'));
```

XFTY decides which by inspecting the ancestor's Provider's Master Template. A
test that configures a shared ancestor it never references still resolves it, so
document which shared ancestors a shipped Provider expects the test to configure
(or have the Provider's own `*LookupKeys`-style setup call `putIfAbsent(...)`).

---

## When to put it in a *shipped* Provider

Only when the shared parent is genuinely part of the model — a singleton config
record, an org-wide root. For a test-specific "these all share one account", it
is clearer to set it on the `XFTY_DummySObjectProvider` instance in that test
with `.putRequired(...)`.

Full behaviour, configuration, and current limits:
[use/shared-ancestors](../use/shared-ancestors.md). Design and the deep-hierarchy
acceptance scenario: [roadmap/shared-ancestors](../roadmap/shared-ancestors.md).
