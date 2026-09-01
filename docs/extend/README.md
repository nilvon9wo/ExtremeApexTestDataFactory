# Extending XFTY for your org

You are here to **teach XFTY about your org's SObjects** — write Providers,
register variants, add custom value expressions. (If you just want to *use* XFTY
to write tests, go to [../use/](../use/).)

| Page | Covers |
|------|--------|
| [providers](providers.md) | Implement `XFTY_DummySobjectProviderIntf` for a new `SObject` type — Master Template, primary target field, relationship design, discovering required fields, testing. |
| [provider-lookups](provider-lookups.md) | Write your project's `XFTY_DummySObjectProviderLookupIntf` over a `Map` + `XFTY_ProviderLookups`; the multi-package compile boundary. |
| [provider-variants](provider-variants.md) | Register more than one Provider per type — `XFTY_RecordTypeLookupKey`, `XFTY_FlavouredLookupKey`, `XFTY_FieldPredicate`, a `*LookupKeys` constants class, resolution and specificity. |
| [custom-value-expressions](custom-value-expressions.md) | Implement `XFTY_ValueExpressionIntf` or `XFTY_ContextAwareExpressionIntf`. |
| [shared-ancestors-in-templates](shared-ancestors-in-templates.md) | Put an `XFTY_SharedAncestor` in a *shipped* Master Template — and when not to. |
| [bundled-providers](bundled-providers.md) | The three shipped Providers + `XFTY_DefaultSObjectProviderLookup` — copy-and-adjust, don't depend on. |

Working on XFTY's own engine instead? → [../contribute/](../contribute/).
