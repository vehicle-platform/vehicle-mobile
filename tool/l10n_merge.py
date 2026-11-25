#!/usr/bin/env python3
"""Merge the per-area ARB fragments l10n_src/parts/<area>.<lang>.json into
lib/l10n/app_<lang>.arb (the keys of l10n_src/base.<lang>.json come first).
Run `python3 tool/l10n_merge.py` and then `flutter gen-l10n`; both outputs are
committed. `--check` fails when the merged files are out of date."""
import json, pathlib, sys

repo = pathlib.Path(__file__).resolve().parent.parent
src = repo / "l10n_src"
root = repo / "lib" / "l10n"
check = "--check" in sys.argv
bad = False
for lang in ("en", "tr"):
    merged = json.loads((src / f"base.{lang}.json").read_text(encoding="utf-8"))
    for part in sorted((src / "parts").glob(f"*.{lang}.json")):
        data = json.loads(part.read_text(encoding="utf-8"))
        for k, v in data.items():
            if k in merged:
                sys.exit(f"duplicate key {k} in {part.name}")
            merged[k] = v
    text = json.dumps(merged, ensure_ascii=False, indent=2) + "\n"
    out = root / f"app_{lang}.arb"
    if check:
        if out.read_text(encoding="utf-8") != text:
            print(f"{out.name} is out of date"); bad = True
    else:
        out.write_text(text, encoding="utf-8")
sys.exit(1 if bad else 0)
