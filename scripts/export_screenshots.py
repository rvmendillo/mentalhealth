#!/usr/bin/env python3
"""Rename attachments exported by `xcresulttool export attachments` to readable names."""
import json, os, re, shutil, sys

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
manifest_path = os.path.join(src, "manifest.json")
if not os.path.exists(manifest_path):
    print("no manifest.json; nothing to rename")
    sys.exit(0)
manifest = json.load(open(manifest_path))
count = 0

def walk(node, test=""):
    global count
    if isinstance(node, dict):
        test = node.get("testIdentifier", test)
        exported = node.get("exportedFileName")
        if exported:
            name = node.get("suggestedHumanReadableName") or exported
            name = re.sub(r"[^A-Za-z0-9._-]+", "-", name)
            if not os.path.splitext(name)[1]:
                name += os.path.splitext(exported)[1] or ".png"
            source = os.path.join(src, exported)
            if os.path.exists(source):
                shutil.copy(source, os.path.join(dst, name))
                count += 1
        for value in node.values():
            walk(value, test)
    elif isinstance(node, list):
        for value in node:
            walk(value, test)

walk(manifest)
print(f"copied {count} attachments to {dst}")
