# About Nimbus

Several contributor docs mention **Nimbus**. This page says what it is, how and
why this project uses it, and the limits of that use.

## What it is

[Nimbus](https://testnimbus.dev/) is a third-party local Apex runtime: it
executes Apex and simulates enough of the Salesforce data layer to run unit
tests **on a developer machine, with no org**. It is not a Salesforce product
and it is not part of the Salesforce platform.

## How this project uses it

Nimbus is a **contributor convenience for the inner loop only**:

- `nimbus test "*"` runs the whole `XFTY_*` suite in a few seconds, so a change
  can be checked continuously while it is being written.
- It is the reason the coding standards call out a handful of
  [fidelity gaps](local-development.md#nimbus--the-fast-inner-loop) — places
  where Nimbus and the real platform differ, which contributors work around.

Nimbus is **never the last word**. Anything that touches record types, Person
Accounts, mixed DML, static-initialiser rollback, governor metering, or any
other area where the two can diverge is confirmed on a real scratch org (and in
CI, which runs against an org) before it is considered done. The tests that
genuinely depend on a real org's schema and query semantics live in
`test-support/main/default/classes/orgonly/` and are excluded from the local
run, which is 100% green.

## What this is not

- **Not an endorsement.** This project has no affiliation with Nimbus or its
  authors, is not sponsored by them, and receives nothing from them. We use the
  freely available CLI and describe our use of it; that is the whole
  relationship.
- **Not a dependency of XFTY.** XFTY is a Salesforce test-data framework; it
  targets the Salesforce platform and has no build-time or run-time dependency
  on Nimbus. Consumers of XFTY do not need it. Contributors do not strictly need
  it either — the scratch-org loop works without it, just more slowly.
- **Not a claim of correctness.** Where a Nimbus result and a documented
  Salesforce behaviour disagree, the platform wins.

## Version

This project's docs and local baselines were last verified against **Nimbus
1.28.0** on **2026-09-01**. Later versions may close some of the recorded
fidelity gaps; re-check them if you upgrade.
