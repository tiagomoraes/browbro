#!/usr/bin/env python3
"""Turn packaging/mas/listing.md into the metadata tree `deliver` uploads.

listing.md stays the single source of truth: it is the file a human writes and
reviews, and it carries the reasoning (character budgets, why a frame exists)
that a directory of bare .txt files cannot. This script projects it into the
layout fastlane expects, so nothing is transcribed twice and the two cannot drift.

The output is generated, not committed — see .gitignore.

Deliberately NOT emitted: App Review contact details (name, phone, email). This
repository is public; that information lives only in App Store Connect. Review
*notes* are emitted, because they describe the product, not a person.

Exits non-zero naming the missing piece if listing.md loses a section, so a bad
edit fails the release instead of silently shipping a blank product page.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
LISTING = ROOT / "packaging" / "mas" / "listing.md"
OUT = ROOT / "fastlane" / "metadata"
LOCALE = "en-US"

# Heading prefix -> file, relative to the locale directory. Prefixes, not exact
# titles, because the headings carry character budgets that change.
BLOCKS = {
    "## Name": "name.txt",
    "## Subtitle": "subtitle.txt",
    "## Promotional text": "promotional_text.txt",
    "## Description": "description.txt",
    "## Keywords": "keywords.txt",
    "## What's New": "release_notes.txt",
}
# Same, for files deliver reads from outside the locale directory.
REVIEW_BLOCKS = {"## App Review notes": "notes.txt"}

# `Label: \`value\`` lines in the preamble.
URLS = {
    "Privacy policy": "privacy_url.txt",
    "Support URL": "support_url.txt",
    "Marketing URL": "marketing_url.txt",
}
ROOT_FIELDS = {"Copyright": "copyright.txt"}


def fenced_block_after(text: str, heading_prefix: str) -> str:
    """The first ``` fenced block following a heading that starts with the prefix."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if not line.startswith(heading_prefix):
            continue
        for j in range(i + 1, len(lines)):
            if lines[j].startswith("```"):
                body = []
                for k in range(j + 1, len(lines)):
                    if lines[k].startswith("```"):
                        return "\n".join(body).strip()
                    body.append(lines[k])
                raise SystemExit(f"✗ Unterminated code fence under '{heading_prefix}'")
            # A new heading before any fence means the section has no block.
            if lines[j].startswith("## "):
                break
        raise SystemExit(f"✗ No fenced block under '{heading_prefix}' in {LISTING}")
    raise SystemExit(f"✗ No heading starting with '{heading_prefix}' in {LISTING}")


def labelled_value(text: str, label: str) -> str:
    m = re.search(rf"^{re.escape(label)}:\s*`([^`]+)`\s*$", text, re.MULTILINE)
    if not m:
        raise SystemExit(f"✗ No '{label}: `…`' line in {LISTING}")
    return m.group(1).strip()


def write(path: pathlib.Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value + "\n", encoding="utf-8")
    first = value.splitlines()[0] if value else ""
    shown = first if len(first) <= 58 else first[:55] + "..."
    print(f"  {path.relative_to(ROOT)}  ({len(value)} chars)  {shown}")


def main() -> int:
    if not LISTING.exists():
        raise SystemExit(f"✗ {LISTING} not found")
    text = LISTING.read_text(encoding="utf-8")

    print(f"▶ {LISTING.relative_to(ROOT)} → {OUT.relative_to(ROOT)}")
    for heading, name in BLOCKS.items():
        write(OUT / LOCALE / name, fenced_block_after(text, heading))
    for heading, name in REVIEW_BLOCKS.items():
        write(OUT / "review_information" / name, fenced_block_after(text, heading))
    for label, name in URLS.items():
        write(OUT / LOCALE / name, labelled_value(text, label))
    for label, name in ROOT_FIELDS.items():
        write(OUT / name, labelled_value(text, label))

    # Cheap guards against the limits Connect enforces, caught here rather than
    # after a build has already been uploaded.
    limits = {LOCALE + "/subtitle.txt": 30, LOCALE + "/keywords.txt": 100,
              LOCALE + "/promotional_text.txt": 170, LOCALE + "/name.txt": 30}
    for rel, limit in limits.items():
        value = (OUT / rel).read_text(encoding="utf-8").strip()
        if len(value) > limit:
            raise SystemExit(f"✗ {rel} is {len(value)} characters, limit is {limit}")
    print("✅ metadata generated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
