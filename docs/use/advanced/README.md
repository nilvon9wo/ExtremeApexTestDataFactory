# Advanced — combining features

Each page here is a scenario that uses several XFTY features together. Read the
individual feature pages in [../](../) first.

| Page | Combines |
|------|----------|
| [unit-vs-integration](unit-vs-integration.md) | one set of Providers, `MOCK` ↔ `NOW` |
| [large-graphs](large-graphs.md) | inclusivity + `PREVENT_CASCADE` + `.depthBatched()` + the governor budget |
| [deep-setup-chains](deep-setup-chains.md) | the `static` fixture pattern, a `static {}` block to `flush()` a `DEFERRED` fixture, then `DEFERRED` across helper methods when steps are ordered and need real DML |
| [matching-values](matching-values.md) | context-aware values + shared ancestors to keep a validation-rule field pair in sync |

▶ Runnable: `XFTY_Ex_Adv_UnitVsIntegrationTest`, `XFTY_Ex_Adv_LargeGraphsTest`,
`XFTY_Ex_Adv_DeepSetupChainsTest`, `XFTY_Ex_Adv_StaticDeferredFixtureTest`,
`XFTY_Ex_Adv_MatchingValuesTest`.
