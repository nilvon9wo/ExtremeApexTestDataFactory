# Continuous Integration

`.github/workflows/ci.yml` runs two jobs on every push and PR against `master`
or `4.0-beta`.

**`doc-examples`** — `scripts/verify-doc-examples.py` (no org needed): every
significant call in every ```apex``` block on a page with a `Runnable:` line
must appear, verbatim, in the test class(es) that line names — a fence marked
`<!-- sketch -->` (illustrative project-specific code, e.g. a consumer's own
SObjects) is exempt. Fails the build the moment a doc example and its test
drift apart. See [coverage-standards](coverage-standards.md).

**`apex-tests`** — creates a scratch org, deploys `force-app` **and**
`test-support`, runs every local test (`RunLocalTests` — so `XFTY_Unit`,
`XFTY_Integration`, `XFTY_Load`, `XFTY_Examples`, `XFTY_OrgOnly`, and
`XFTY_PersonAccount`), and deletes the scratch org. The scratch org enables
`PersonAccounts` so the Person Account tests run.

---

## The one secret

`DEVHUB_SFDX_AUTH_URL` — a repository secret:

```bash
# authenticate the Dev Hub locally, then print its auth URL
sf org display --target-org devhub --verbose --json | jq -r '.result.sfdxAuthUrl'
```

Copy the `force://...` value into
**Settings → Secrets and variables → Actions → New repository secret**. Treat it
like a password — it grants full access to that Dev Hub.
