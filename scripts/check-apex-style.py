#!/usr/bin/env python3
"""
Apex style / safety checks.

Two tiers:

* **Whole-tree, always** — things that do not compile on a real Salesforce org
  (the local runtime lets them through):
    - an identifier longer than 40 characters (class file names);
    - `@IsTest` on an `interface`;
    - an Apex reserved word (`not`, `inner`, `like`, `outer`, …) used as an
      identifier - a field/local declaration, a method name, or a `.method()`
      call. The local runtime accepts several of these; a real org does not.

* **Changed files only** — the project's test-style rules, applied to the `.cls`
  files a push / PR actually touches, so new code must comply without forcing a
  retrofit of every legacy test:
    - no `System.assert` / `System.assertEquals` / `System.assertNotEquals`
      (use `Assert.*`);
    - every `@IsTest` method carries `// Arrange`, `// Act`, `// Assert` markers;
    - no local variable that shadows an SObject type (`Contact contact`);
    - no method with more than 3 parameters.

Usage:
    check-apex-style.py                      # whole-tree checks only
    check-apex-style.py <file.cls> ...       # + changed-file checks on those
    check-apex-style.py --changed <ref>      # + changed-file checks vs a git ref
"""
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIRS = [os.path.join(ROOT, "force-app"), os.path.join(ROOT, "test-support")]
MAX_IDENTIFIER = 40
MAX_PARAMS = 3

SOBJECTS = (
    "Account Contact Case Opportunity Lead User Task Event Group Profile "
    "Pricebook2 Product2 Asset Order Contract Campaign Attachment Document "
    "Folder Site Organization Territory Note Idea"
).split()

# Apex reserved words that are NOT also words the local Nimbus runtime rejects
# as identifiers. Kept to the ones a person might reach for as a variable or
# method name; `class`, `return`, `new`, … are not worth listing.
RESERVED_WORDS = (
    "not inner outer like asc desc having hint join sort when from limit group where"
).split()

failures = []


def fail(path, msg):
    failures.append(f"{os.path.relpath(path, ROOT)}: {msg}")


def all_cls():
    for d in SRC_DIRS:
        for dp, _, fs in os.walk(d):
            for f in fs:
                if f.endswith(".cls"):
                    yield os.path.join(dp, f)


def is_single_call(body: str) -> bool:
    """True when the method body is one call statement and nothing else -
    `helperName(arg, arg, ...);` possibly spread over several lines."""
    code = re.sub(r"//[^\n]*", "", body).strip()
    # one identifier, one parenthesised argument list (no ';' inside - args never
    # carry statements), one trailing ';', nothing else.
    return re.fullmatch(r"[A-Za-z_]\w*\s*\([^;]*\)\s*;", code, flags=re.S) is not None


def split_params(param_text: str):
    """Split a parameter list on top-level commas only - commas inside the angle
    brackets of a generic type (`Map<Id, Account>`) do not separate parameters."""
    parts, depth, current = [], 0, ""
    for ch in param_text:
        if ch in "<(":
            depth += 1
        elif ch in ">)":
            depth = max(0, depth - 1)
        if ch == "," and depth == 0:
            parts.append(current)
            current = ""
        else:
            current += ch
    parts.append(current)
    return [p for p in parts if p.strip()]


def strip_block_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", "", src, flags=re.S)
    src = re.sub(r"//[^\n]*", "", src)
    return src


def strip_strings(src: str) -> str:
    """Blank out Apex string literals so a reserved word inside `'strategic-not'`
    is not mistaken for an identifier. Leaves the quotes and length alone."""
    return re.sub(r"'(?:[^'\\]|\\.)*'", lambda m: "'" + " " * (len(m.group(0)) - 2) + "'", src)


def method_bodies(src: str):
    """Yield (name, params_text, body) for every @IsTest method."""
    for m in re.finditer(
        r"@IsTest\s+(?:(?:static|public|private|protected|global)\s+)*void\s+(\w+)\s*\(([^)]*)\)\s*\{",
        src,
    ):
        depth = 0
        start = m.end() - 1
        for j in range(start, len(src)):
            if src[j] == "{":
                depth += 1
            elif src[j] == "}":
                depth -= 1
                if depth == 0:
                    yield m.group(1), m.group(2), src[m.end():j]
                    break


# ---- whole-tree checks ------------------------------------------------------

def check_tree():
    for path in all_cls():
        stem = os.path.basename(path)[:-4]
        if len(stem) > MAX_IDENTIFIER:
            fail(path, f"class name is {len(stem)} chars (Apex limit is {MAX_IDENTIFIER})")
        # strip comments first, so a commented-out `//@IsTest` above an
        # interface (the correct pattern) is not flagged
        src = strip_block_comments(open(path, encoding="utf-8").read())
        if re.search(r"@IsTest\s+(?:(?:public|global)\s+)*interface\b", src):
            fail(path, "@IsTest on an interface (Salesforce rejects it; use //@IsTest)")

        code = strip_strings(src)
        for word in RESERVED_WORDS:
            for m in re.finditer(
                rf"(?:\b[A-Za-z_]\w*(?:<[^>;{{}}]*>)?\s+|\.\s*){word}\s*(?:[=;,)]|\()",
                code,
            ):
                line = code[: m.start()].count("\n") + 1
                fail(path, f"line {line}: `{word}` is an Apex reserved word - cannot be an identifier")


# ---- changed-file checks --------------------------------------------------

def check_changed(paths):
    for path in paths:
        if not path.endswith(".cls") or not os.path.exists(path):
            continue
        raw = open(path, encoding="utf-8").read()
        src = strip_block_comments(raw)

        for am in re.finditer(r"\bSystem\.assert(?:Equals|NotEquals)?\s*\(", src):
            line = src[: am.start()].count("\n") + 1
            fail(path, f"line {line}: System.assert* - use Assert.* (areEqual / isTrue / etc)")

        for stype in SOBJECTS:
            for vm in re.finditer(rf"\b{stype}\s+({stype.lower()})\b\s*[=;)]", src):
                line = src[: vm.start()].count("\n") + 1
                fail(path, f"line {line}: local `{vm.group(1)}` shadows the `{stype}` type - rename it")

        for m in re.finditer(
            r"\b(?:static|public|private|protected|global)\b[^;{}=]*?\b(\w+)\s*\(([^)]*)\)\s*\{",
            src,
        ):
            params = split_params(m.group(2))
            if len(params) > MAX_PARAMS:
                line = src[: m.start()].count("\n") + 1
                fail(path, f"line {line}: {m.group(1)}(...) has {len(params)} parameters (max {MAX_PARAMS})")

        if path.endswith("Test.cls") or "/tests/" in path.replace(os.sep, "/"):
            for name, _params, body in method_bodies(raw):
                if is_single_call(body):
                    # A parameterised test that delegates to a shared helper -
                    # the // Arrange / // Act / // Assert live in the helper.
                    continue
                if not (
                    re.search(r"//\s*Arrange", body)
                    and re.search(r"//\s*Act", body)
                    and re.search(r"//\s*Assert", body)
                ):
                    fail(path, f"@IsTest {name}: missing one of the // Arrange / // Act / // Assert markers")


def changed_via_git(ref):
    out = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=d", f"{ref}...HEAD"],
        cwd=ROOT, capture_output=True, text=True, check=True,
    ).stdout
    return [os.path.join(ROOT, p) for p in out.split() if p.endswith(".cls")]


def main() -> int:
    args = sys.argv[1:]
    check_tree()

    changed = []
    if args and args[0] == "--changed":
        changed = changed_via_git(args[1])
    elif args:
        changed = [os.path.abspath(a) for a in args]

    if changed:
        check_changed(changed)
        print(f"style: {len(changed)} changed .cls file(s) checked")
    else:
        print("style: whole-tree safety checks only (no changed files given)")

    if failures:
        print(f"\n{len(failures)} style issue(s):\n")
        print("\n".join("  " + f for f in failures))
        return 1
    print("no style issues")
    return 0


if __name__ == "__main__":
    sys.exit(main())
