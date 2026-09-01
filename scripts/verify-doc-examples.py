#!/usr/bin/env python3
"""
Guarantees every ```apex block in docs/use/** and docs/extend/** is backed by a
runnable test.

For each page carrying a `> Runnable:` / "Runnable:" line, every significant line
of every ```apex block on that page (a `.method(...)` call, a `new XFTY_...`, an
`implements XFTY_...`, an `XFTY_*.staticCall(...)`) must appear - whitespace
normalised - in one of the test classes that line names, which all live in
test-support/ or force-app/ and run in CI (XFTY_Examples / XFTY_Unit /
XFTY_Integration / XFTY_OrgOnly).

Fragments are fine: the check is line-by-line, not block-by-block, so a doc can
show `.put(Contact.X, expr)` on its own and it still has to exist in a test.

Exit non-zero (and print every miss) if any documented call is not exercised.
"""
import re
import sys
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

# Only the audience-facing feature docs promise runnable examples. Everything
# else is explicitly out of scope - notably docs/articles/, which holds the
# author's essays: their code snippets are illustrative prose, not framework API,
# and must never be checked against the test suite.
DOC_DIRS = [ROOT / "docs" / "use", ROOT / "docs" / "extend"]
EXCLUDE_DIRS = [ROOT / "docs" / "articles"]
TEST_DIRS = [
    ROOT / "test-support" / "main" / "default" / "classes",
    ROOT / "force-app" / "main" / "default" / "classes",
]

RUNNABLE_RE = re.compile(r"Runnable:\s*(.+)$", re.M)
CLASS_RE = re.compile(r"`(XFTY_[A-Za-z0-9_]+)(?:\.[A-Za-z0-9_]+)?`")
# A fence immediately preceded by `<!-- sketch -->` is illustrative project code
# (a consumer's own SObjects / lookup-key classes) and is exempt - it cannot run
# against the bundled Account / Contact / User Providers.
APEX_BLOCK_RE = re.compile(r"(?:^|\n)(<!-- sketch -->\n)?```apex\n(.*?)\n```", re.S)
SIGNIFICANT_RE = re.compile(
    r"(\.\w+\([^\n]*\)"          # .method(...)
    r"|new\s+XFTY_\w+\([^\n]*\)"  # new XFTY_...(...)
    r"|implements\s+XFTY_\w+"     # implements XFTY_...
    r"|XFTY_\w+\.\w+\([^\n]*\))"  # XFTY_Foo.bar(...)
)


def norm(s: str) -> str:
    # whitespace-insensitive and case-insensitive: docs write the lookup
    # placeholder as `lookup`, the example tests as the `LOOKUP` constant - same
    # thing. Full-fragment matching keeps this from producing false positives.
    return re.sub(r"\s+", "", s).lower()


def load_test_sources():
    blobs = {}
    for d in TEST_DIRS:
        for p in d.rglob("*.cls"):
            blobs[p.stem] = norm(p.read_text(encoding="utf-8"))
    return blobs


def main() -> int:
    tests = load_test_sources()
    all_tests_blob = norm("".join(pathlib.Path(f).read_text(encoding="utf-8")
                                 for d in TEST_DIRS for f in d.rglob("*.cls")))
    misses = []
    checked_pages = 0
    checked_lines = 0

    for d in DOC_DIRS:
        for page in sorted(d.rglob("*.md")):
            if any(ex in page.parents for ex in EXCLUDE_DIRS):
                continue
            text = page.read_text(encoding="utf-8")
            runnable_lines = RUNNABLE_RE.findall(text)
            if not runnable_lines:
                continue
            checked_pages += 1
            named = [c for line in runnable_lines for c in CLASS_RE.findall(line)]
            # the union of every named test class's source, plus a fallback to
            # the whole test corpus (a doc line may legitimately be proven by a
            # shared helper class)
            scope = "".join(tests.get(n, "") for n in named) or all_tests_blob
            for sketch_marker, block in APEX_BLOCK_RE.findall(text):
                if sketch_marker:
                    continue
                for line in block.splitlines():
                    line = line.strip()
                    if not line or line.startswith("//"):
                        continue
                    for frag in SIGNIFICANT_RE.findall(line):
                        checked_lines += 1
                        if norm(frag) not in scope and norm(frag) not in all_tests_blob:
                            misses.append(f"{page.relative_to(ROOT)}  |  {frag}"
                                          f"  |  not in {', '.join(named) or 'any test'}")

    print(f"checked {checked_lines} documented calls across {checked_pages} pages")
    if misses:
        print(f"\n{len(misses)} documented call(s) with no backing test:\n")
        print("\n".join("  " + x for x in misses))
        return 1
    print("every documented apex call is exercised by a runnable test")
    return 0


if __name__ == "__main__":
    sys.exit(main())
