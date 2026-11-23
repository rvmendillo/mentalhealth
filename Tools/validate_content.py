#!/usr/bin/env python3
"""Validate Renewed Mind's bundled content against public-domain sources.

Checks, for every affirmation, practice, and etymology card:
  * the verse text is an exact excerpt of the Berean Standard Bible (BSB, public domain)
  * the Strong's number of each word study occurs in that verse (BSB interlinear tables)
  * the Hebrew/Greek lemma matches Strong's dictionary (Open Scriptures edition)
  * the English gloss appears in the verse
  * cross-references between files resolve

Usage: python3 Tools/validate_content.py [--cache DIR]
Downloads ~90 MB of reference data on first run.
"""
import argparse, json, os, re, sys, unicodedata, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "Packages", "RenewedMindKit", "Sources", "RenewedMindKit", "Resources")
SOURCES = {
    "bsb.txt": "https://bereanbible.com/bsb.txt",
    "bsb_tables.tsv": "https://bereanbible.com/bsb_tables.tsv",
    "strongs-hebrew.js": "https://raw.githubusercontent.com/openscriptures/strongs/master/hebrew/strongs-hebrew-dictionary.js",
    "strongs-greek.js": "https://raw.githubusercontent.com/openscriptures/strongs/master/greek/strongs-greek-dictionary.js",
}
REF_RE = re.compile(r"^(?P<book>.+?) (?P<ch>\d+):(?P<v1>\d+)(?:[–-](?P<v2>\d+))?$")


def fetch(cache):
    os.makedirs(cache, exist_ok=True)
    for name, url in SOURCES.items():
        path = os.path.join(cache, name)
        if not os.path.exists(path) or os.path.getsize(path) == 0:
            print(f"downloading {url}")
            req = urllib.request.Request(url, headers={"User-Agent": "renewed-mind-content-validator"})
            with urllib.request.urlopen(req, timeout=300) as r, open(path, "wb") as f:
                f.write(r.read())


def load_js_object(path):
    text = open(path, encoding="utf-8").read()
    return json.loads(text[text.index("{", text.index("= {")): text.rindex("}") + 1])


def load(cache):
    verses = {}
    for line in open(os.path.join(cache, "bsb.txt"), encoding="utf-8-sig"):
        line = line.rstrip("\r\n")
        if "\t" in line:
            ref, text = line.split("\t", 1)
            if re.match(r"^[1-3]?\s?[A-Za-z ]+ \d+:\d+$", ref):
                verses[ref] = text
    words, current = {}, None
    with open(os.path.join(cache, "bsb_tables.tsv"), encoding="utf-8") as f:
        header = f.readline().rstrip("\r\n").split("\t")
        col = {h: i for i, h in enumerate(header)}
        for line in f:
            cols = line.rstrip("\r\n").split("\t")
            cols += [""] * (len(header) - len(cols))
            if cols[col["VerseId"]].strip():
                current = cols[col["VerseId"]].strip()
            heb, grk = cols[col["Str Heb"]].strip(), cols[col["Str Grk"]].strip()
            num = "H" + heb if heb else ("G" + grk if grk else "")
            if current and num:
                words.setdefault(current, set()).add(num)
    strongs = {}
    strongs.update(load_js_object(os.path.join(cache, "strongs-hebrew.js")))
    strongs.update(load_js_object(os.path.join(cache, "strongs-greek.js")))
    return verses, words, strongs


def expand(ref):
    m = REF_RE.match(ref)
    if not m:
        return None
    v1, v2 = int(m["v1"]), int(m["v2"] or m["v1"])
    return [f"{m['book']} {m['ch']}:{v}" for v in range(v1, v2 + 1)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", default=os.path.join(ROOT, ".content-cache"))
    args = ap.parse_args()
    fetch(args.cache)
    verses, words, strongs = load(args.cache)
    errors = []

    def check_verse(kind, item_id, ref, text):
        refs = expand(ref or "")
        if not refs:
            errors.append(f"{kind} {item_id}: bad reference {ref!r}")
            return None
        missing = [r for r in refs if r not in verses]
        if missing:
            errors.append(f"{kind} {item_id}: unknown verse {missing}")
            return None
        full = " ".join(verses[r] for r in refs)
        if not text or text not in full:
            errors.append(f"{kind} {item_id}: verse text is not an exact BSB excerpt of {ref}")
        return refs

    affirmations = json.load(open(os.path.join(RES, "affirmations.json"), encoding="utf-8"))
    practices = json.load(open(os.path.join(RES, "practices.json"), encoding="utf-8"))
    citations = json.load(open(os.path.join(RES, "citations.json"), encoding="utf-8"))
    etymologies = json.load(open(os.path.join(RES, "etymologies.json"), encoding="utf-8"))

    ids = [a["id"] for a in affirmations]
    if len(ids) != len(set(ids)):
        errors.append("duplicate affirmation ids")
    for a in affirmations:
        refs = check_verse("affirmation", a["id"], a["reference"], a["verse"])
        ws = a["wordStudy"]
        num = ws["strongs"]
        if refs and not any(num in words.get(r, set()) for r in refs):
            errors.append(f"affirmation {a['id']}: {num} does not occur in {a['reference']}")
        entry = strongs.get(num)
        if not entry:
            errors.append(f"affirmation {a['id']}: {num} not in Strong's dictionary")
        elif unicodedata.normalize("NFC", entry["lemma"]) != unicodedata.normalize("NFC", ws["lemma"]):
            errors.append(f"affirmation {a['id']}: lemma {ws['lemma']} != Strong's {entry['lemma']}")
        if ws["language"] != ("hebrew" if num.startswith("H") else "greek"):
            errors.append(f"affirmation {a['id']}: language mismatch")
        if ws["english"].lower() not in a["verse"].lower():
            errors.append(f"affirmation {a['id']}: gloss {ws['english']!r} not in verse")

    citation_ids = {c["id"] for c in citations}
    for p in practices:
        check_verse("practice", p["id"], p["reference"], p["verse"])
        for c in p["citations"]:
            if c not in citation_ids:
                errors.append(f"practice {p['id']}: unknown citation {c}")
    for e in etymologies:
        if e.get("reference"):
            check_verse("etymology", e["id"], e["reference"], e.get("verse"))

    print(f"checked {len(affirmations)} affirmations, {len(practices)} practices, "
          f"{len(etymologies)} etymologies, {len(citations)} citations")
    if errors:
        print("\n".join("ERROR: " + e for e in errors))
        sys.exit(1)
    print("All content verified against the BSB text, BSB interlinear, and Strong's dictionary.")


if __name__ == "__main__":
    main()
