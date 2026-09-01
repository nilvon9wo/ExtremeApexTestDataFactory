# Contributing to XFTY

You are here to **work on XFTY itself** — the engine, its tests, packaging.

| Page | Covers |
|------|--------|
| [coding-standards](coding-standards.md) | The rules XFTY code is held to — the review checklist. Read this first. |
| [architecture](architecture.md) | The generation pipeline, the phase classes, the generation context, the value passes, mock Ids, immutability — and *why* each is shaped that way. |
| [local-development](local-development.md) | Scratch-org loop, Nimbus (local Apex runtime + its known gaps), measuring line coverage. |
| [about-nimbus](about-nimbus.md) | What Nimbus is, how/why this project uses it, and that it is neither endorsed nor a dependency. Version and date. |
| [test-suites](test-suites.md) | `XFTY_Unit` / `XFTY_Integration` / `XFTY_Load` / `XFTY_Examples` — contents and when to run. |
| [coverage-standards](coverage-standards.md) | "A consumer must never have to debug the framework"; line floor vs branch goal. |
| [packaging](packaging.md) | Source format, the `test-support/` split, unlocked-package build. |
| [ci](ci.md) | What the GitHub Actions workflow runs; the Dev Hub secret. |

For what is built / in progress / proposed, see [../roadmap/](../roadmap/). For
the one open question that blocks work, see
[../roadmap/open-questions.md](../roadmap/open-questions.md).

House style is not optional — the full rules are in
[coding-standards](coding-standards.md). The short version: be lazy, communicate
intent, balance separation and encapsulation; short shallow methods, one
expression per line, ≤3 params, multi-line ternaries, flyweights, explicit maps
over registries; fix defects on the branch in their own commits.
