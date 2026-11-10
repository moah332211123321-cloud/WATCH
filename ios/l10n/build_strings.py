"""Builds App/Resources/Localizable.xcstrings from the L("…") / S("…") keys in the app and ar.json.

    python -I ios/l10n/build_strings.py          # writes the catalog; exit 1 if any key lacks Arabic
    python -I ios/l10n/build_strings.py --list   # prints keys missing a translation

English is the key itself. Standard library only.
"""
import glob
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(HERE, "..", "App")
KEY = re.compile(r'\b[LS]\("((?:[^"\\]|\\.)*)"\)')


def keys():
    found = set()
    for path in glob.glob(os.path.join(APP, "**", "*.swift"), recursive=True):
        with open(path, encoding="utf-8") as f:
            found.update(m.group(1) for m in KEY.finditer(f.read()))
    return sorted(found)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    with open(os.path.join(HERE, "ar.json"), encoding="utf-8") as f:
        ar = json.load(f)
    all_keys = keys()
    missing = [k for k in all_keys if not ar.get(k)]
    if "--list" in sys.argv:
        for k in missing:
            print(k)
        return 0 if not missing else 1
    strings = {}
    for k in all_keys:
        entry = {"extractionState": "manual", "localizations": {}}
        if k == "percent":  # unit key with a different English text
            entry["localizations"]["en"] = {"stringUnit": {"state": "translated", "value": "%"}}
        if ar.get(k):
            entry["localizations"]["ar"] = {"stringUnit": {"state": "translated", "value": ar[k]}}
        strings[k] = entry
    catalog = {"sourceLanguage": "en", "strings": strings, "version": "1.0"}
    out = os.path.join(APP, "Resources", "Localizable.xcstrings")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(catalog, f, ensure_ascii=False, indent=2)
    unused = sorted(set(ar) - set(all_keys))
    print(f"{len(all_keys)} keys, {len(missing)} missing Arabic, {len(unused)} unused translations")
    for k in missing:
        print("MISSING:", k)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
