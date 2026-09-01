#!/usr/bin/env python3
"""
Every relative link in docs/** must resolve.

For every `](target)` in every `docs/**/*.md`:
  - a link to a file (optionally with a `#anchor`) must point at a real path,
    resolved relative to the containing file;
  - if it carries a `#anchor`, the target file must have a heading whose GitHub
    slug matches.

`http(s)://` and `mailto:` links are not checked. Exit non-zero (listing every
break) on the first unresolved link.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
LINK_RE = re.compile(r"\]\(([^)]+)\)")
HEADING_RE = re.compile(r"^#{1,6}\s+(.*?)\s*$")


def slug(heading: str) -> str:
    # GitHub's algorithm: lowercase, drop anything that is not word/space/hyphen,
    # spaces to hyphens.
    s = heading.strip().lower()
    s = re.sub(r"[^\w\s-]", "", s)
    return s.replace(" ", "-")


def headings_of(path: str) -> set:
    out = set()
    with open(path, encoding="utf-8") as fh:
        in_fence = False
        for line in fh:
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            m = HEADING_RE.match(line)
            if m:
                out.add(slug(m.group(1)))
    return out


def main() -> int:
    heading_cache = {}
    broken = []
    checked = 0

    for dirpath, _, filenames in os.walk(DOCS):
        for name in filenames:
            if not name.endswith(".md"):
                continue
            page = os.path.join(dirpath, name)
            with open(page, encoding="utf-8") as fh:
                lines = fh.readlines()
            in_fence = False
            for lineno, line in enumerate(lines, 1):
                if line.lstrip().startswith("```"):
                    in_fence = not in_fence
                    continue
                if in_fence:
                    continue
                for target in LINK_RE.findall(line):
                    target = target.strip()
                    if target.startswith(("http://", "https://", "mailto:", "#")):
                        # bare in-page anchors (#foo) are not checked here
                        continue
                    checked += 1
                    path_part, _, anchor = target.partition("#")
                    dest = os.path.normpath(os.path.join(dirpath, path_part)) if path_part else os.path.normpath(page)
                    if not os.path.exists(dest):
                        broken.append(f"{os.path.relpath(page, ROOT)}:{lineno}  missing file  ->  {target}")
                        continue
                    if anchor and dest.endswith(".md"):
                        if dest not in heading_cache:
                            heading_cache[dest] = headings_of(dest)
                        if slug(anchor) not in heading_cache[dest]:
                            broken.append(f"{os.path.relpath(page, ROOT)}:{lineno}  missing anchor  ->  {target}")

    print(f"checked {checked} relative links across docs/")
    if broken:
        print(f"\n{len(broken)} broken link(s):\n")
        print("\n".join("  " + b for b in broken))
        return 1
    print("every relative link and anchor resolves")
    return 0


if __name__ == "__main__":
    sys.exit(main())
