# Contributing to XFTY

You are here to **work on XFTY itself** — the engine, its tests, packaging.

| Page | Covers |
|------|--------|
| [architecture](architecture.md) | The generation pipeline, the phase classes, the generation context, the value passes, mock Ids, immutability — and *why* each is shaped that way. |
| [local-development](local-development.md) | Scratch-org loop, Nimbus (local Apex runtime + its known gaps), measuring line coverage. |
| [test-suites](test-suites.md) | `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` / `XFTY_Examples` — contents and when to run. |
| [coverage-standards](coverage-standards.md) | "A consumer must never have to debug the framework"; line floor vs branch goal. |
| [packaging](packaging.md) | Source format, the `test-support/` split, unlocked-package build. |
| [ci](ci.md) | What the GitHub Actions workflow runs; the Dev Hub secret. |

For what is built / in progress / proposed, see [../roadmap/](../roadmap/).

## House style

- Fix defects on the working branch, in their own commits.
- Prefer flyweights; prefer complete explicit maps + stateless utilities over
  registries and stateful builders.
- Keep methods short and shallow; one expression per line; decompose nested
  calls into named locals; keep ternaries but break them across lines.
- Commit trailers: `Co-Authored-By:` and `Claude-Session:` where applicable.
