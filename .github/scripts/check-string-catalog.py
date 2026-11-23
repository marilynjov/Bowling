#!/usr/bin/env python3
"""Fails when a string the app's code uses is missing from Bowling/Localizable.xcstrings.

A command-line build never rewrites the catalog, and StringCatalogTests can't see a key
that isn't there, so this compares the keys the compiler extracted (the Bowling target's
.stringsdata files from the last build) with the catalog's. Fix a failure by building in
Xcode, which syncs the catalog, or with `xcrun xcstringstool sync`.

Usage: check-string-catalog.py [derived data directory, default ~/Library/Developer/Xcode/DerivedData]
"""
import glob
import json
import os
import sys

root = os.path.expanduser(sys.argv[1] if len(sys.argv) > 1 else "~/Library/Developer/Xcode/DerivedData")
pattern = os.path.join(root, "**", "Bowling.build", "*-iphonesimulator", "Bowling.build", "Objects-normal", "*", "*.stringsdata")
files = glob.glob(pattern, recursive=True)
if not files:
    sys.exit(f"No Bowling .stringsdata under {root}; build the app first.")
# Only the newest build's directory, in case several derived data folders exist.
newest = max({os.path.dirname(f) for f in files}, key=os.path.getmtime)

used = {}
for path in glob.glob(os.path.join(newest, "*.stringsdata")):
    with open(path) as f:
        for entries in json.load(f).get("tables", {}).values():
            for entry in entries:
                used.setdefault(entry["key"], os.path.basename(path).removesuffix(".stringsdata"))

catalog = os.path.join(os.path.dirname(__file__), "..", "..", "Bowling", "Localizable.xcstrings")
with open(catalog) as f:
    keys = set(json.load(f)["strings"])

missing = sorted(set(used) - keys)
for key in missing:
    print(f"::error::Missing from Localizable.xcstrings: {key!r} ({used[key]}.swift)")
if missing:
    sys.exit(f"{len(missing)} strings are missing from the String Catalog.")
print(f"All {len(used)} strings from {newest} are in the String Catalog.")
