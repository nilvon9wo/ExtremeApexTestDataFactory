# Continuous Integration

`.github/workflows/ci.yml` runs on every push and PR against `master`: it creates
a scratch org, deploys `force-app` **and** `test-support`, runs every local test
(`RunLocalTests` — so `XFTY_Unit`, `XFTY_Integration`, `XFTY_Load`,
`XFTY_Examples`, and the loose `test-support` tests), and deletes the scratch
org. The scratch org enables `PersonAccounts` so the Person Account tests run.

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
