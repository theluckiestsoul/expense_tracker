#!/usr/bin/env python3
import hashlib
import pathlib
import re
import sys

files = sorted(pathlib.Path("ExpenseTracker/Resources").glob("*.lproj/Localizable.strings"))
expected_keys = None
seen_hashes: dict[str, pathlib.Path] = {}
errors: list[str] = []

for path in files:
    entries = re.findall(r'^"((?:[^"\\]|\\.)*)" = "((?:[^"\\]|\\.)*)";$', path.read_text(), re.MULTILINE)
    keys = [key for key, _ in entries]
    values = [value for _, value in entries]
    if expected_keys is None:
        expected_keys = keys
    elif keys != expected_keys:
        errors.append(f"{path}: keys or key order differ from other localizations")
    if any(not value.strip() for value in values):
        errors.append(f"{path}: contains an empty translation")
    if any("|" in value or "�" in value for value in values):
        errors.append(f"{path}: contains a known machine-translation artifact")
    if any(re.search(r"(?:^|\\s)[0-9०-९]+(?:\\.[0-9]+)+\\.?$", value) for value in values):
        errors.append(f"{path}: contains a suspicious trailing version/footnote")
    digest = hashlib.sha256("\n".join(values).encode()).hexdigest()
    if digest in seen_hashes:
        errors.append(f"{path}: duplicates {seen_hashes[digest]} instead of providing a native translation")
    seen_hashes[digest] = path

if errors:
    print("\n".join(errors), file=sys.stderr)
    raise SystemExit(1)
print(f"Localization quality checks passed for {len(files)} language packs")
