# Test Suites

XFTY defines `ApexTestSuite`s so you can run only what you need.

| Suite | Location | What's in it | When to run |
|-------|----------|--------------|-------------|
| `XFTY_Unit` | `force-app` | Every class that generates with `MOCK` / `NEVER` / `LATER` only — no framework DML, no dependency on org data. Includes the whole generation engine. | Constantly, while developing. Fastest. |
| `XFTY_Integration` | `force-app` | The classes that do real DML — `NOW` / `RELATED_ONLY` insert modes and the bundled Providers persisting records. Sensitive to org config. | Before a commit; in CI. |
| `XFTY_Load` | `test-support` | `XFTY_LoadTest`, `XFTY_SharedAncestorLoadTest`, `XFTY_DeferredLoadTest` — push generation toward each governor limit and pin where it breaks ([../reference/volume-and-limits.md](../reference/volume-and-limits.md)). Assertions assume a quiet org, so it is **not** shipped — and **not** run in CI (a shared runner lacks the CPU headroom for its bulk inserts). | On demand, and when changing the engine. Slowest. |
| `XFTY_Examples` | `test-support` | `XFTY_Ex_*Test` — the runnable versions of every [use/](../use/) doc example. Guards the documented public API. | With the docs; in CI. |
| `XFTY_OrgOnly` | `test-support/orgonly` | Tests that need a real org's schema / query semantics — a custom object's record-type describe, real `Profile` / `UserRole` tables, record-type query counting, the deep-hierarchy acceptance test. Excluded from the local `nimbus test` run ([about-nimbus](about-nimbus.md)). Runs on **any** Developer Edition or scratch org. | On a scratch org, in CI. |
| `XFTY_PersonAccount` | `test-support/orgonly` | `XFTY_PersonAccountVariantTest` only — kept out of `XFTY_OrgOnly` because it needs a **Person-Account-enabled** org, which a package / test cannot turn on. Deploy `XFTY_PersonAccountDataProvider` alongside it. | On a Person-Account org, in CI. |

```bash
sf apex run test --suite-names XFTY_Unit --result-format human            # fast loop
sf apex run test --suite-names XFTY_Unit --suite-names XFTY_Integration   # pre-commit
sf apex run test --suite-names XFTY_Load                                  # engine changes (needs test-support deployed)
sf apex run test --suite-names XFTY_Examples                              # doc examples
sf apex run test --suite-names XFTY_OrgOnly                               # scratch org only
```

Keep test classes single-purpose — suites group by class. A class that mixes
DML-free and DML-backed methods is split (e.g. `XFTY_DummySObjectFactoryTest`
keeps the no-DML matrix; `XFTY_DummySObjectFactoryDmlTest` has the `NOW` /
`RELATED_ONLY` cases). A class with two clearly different *jobs* is also split:
`XFTY_DummySObjectProviderApiTest` (one test per fluent-API affordance) vs.
`XFTY_DummySObjectProviderScenarioTest` (end-to-end "does the whole flow work").
Each test class lives in the same folder as the class it exercises.

`XFTY_RecordTypeRealRtTest` is in `XFTY_OrgOnly` (it was retargeted off
`PersonAccount` onto the `XFTY_HierarchyNode__c` custom object, so it no longer
needs the feature). Only `XFTY_PersonAccountVariantTest` still does — hence its
own `XFTY_PersonAccount` suite.
