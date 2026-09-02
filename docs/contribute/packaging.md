# Packaging

XFTY is a Salesforce DX project in **source format**. Everything deployable lives
under `force-app/`.

`force-app/main/default/classes/` is organised by area — `core/` (the public
types), `engine/` (the generation pipeline), `persistence/` (Id assignment,
deferred / depth-batched insert), `values/`, `relationships/`, `lookup/`,
`predicates/` (the reusable `XFTY_SObjectPredicateIntf` conditions a flavoured
lookup key matches on), `providers/`. **Each class's test sits in the same folder
as the class it tests** — `XFTY_Foo.cls` and `XFTY_FooTest.cls` side by side. The `test-support/`
package directory holds examples that need an org feature the published package
must not require — currently a Person Account Provider, its variant test, the
"real record type" tests, and the `XFTY_Ex_*` doc examples — and is **not** part
of the distributable package (`"default": false` in `sfdx-project.json`, excluded
from `sf package version create`, deployed to scratch/dev orgs).

- Local development, scratch orgs, Nimbus: [local-development](local-development.md)
- Test suites: [test-suites](test-suites.md)
- CI: [ci](ci.md)

---

## Consuming XFTY (no namespace, today)

Deploy the classes straight into a scratch org, sandbox, or production org:

```bash
sf project deploy start --source-dir force-app --target-org <alias>
```

Or convert to an **unlocked package** (no namespace) for versioned installs:

```bash
sf package create --name XFTY --package-type Unlocked --path force-app
sf package version create --package XFTY --installation-key-bypass --wait 20 --code-coverage
sf package install --package XFTY@x.y.z-n --target-org <alias> --wait 10
```

`sf package create` writes the package id and alias back into
`sfdx-project.json`.

---

## Namespace / AppExchange

The medium-term goal is an AppExchange listing under the namespace `XFTY`. It
does not change the workflow above. Plan and open questions:
[../roadmap/namespace-appexchange.md](../roadmap/namespace-appexchange.md).
