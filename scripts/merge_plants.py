#!/usr/bin/env python3
"""
merge_plants.py — Merge new species into RadicleBotany Plants.json.

Reads all new_plants_*.json files from the scripts/ directory,
deduplicates against the existing Plants.json, merges, sorts
alphabetically by scientific name, and writes the updated Plants.json.

Usage:
  python3 scripts/merge_plants.py                # merge all new_plants_*.json
  python3 scripts/merge_plants.py --preview      # show what would be merged
  python3 scripts/merge_plants.py --file new_plants_northeast.json  # merge specific file
"""

import argparse
import glob
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
PLANTS_JSON = PROJECT_DIR / "RadicleBotany" / "Plants.json"


def main():
    parser = argparse.ArgumentParser(description="Merge new species into Plants.json")
    parser.add_argument("--file", type=str, default=None,
                        help="Specific new_plants file to merge (default: all new_plants_*.json)")
    parser.add_argument("--preview", action="store_true",
                        help="Preview what would be merged without writing")
    parser.add_argument("--no-backup", action="store_true",
                        help="Skip creating a backup of Plants.json")
    args = parser.parse_args()

    # Load existing Plants.json
    if not PLANTS_JSON.exists():
        print(f"Error: {PLANTS_JSON} not found")
        sys.exit(1)

    with open(PLANTS_JSON, "r") as f:
        existing = json.load(f)
    print(f"Existing Plants.json: {len(existing)} species")

    existing_names = {p["Plant_Name_Latin"] for p in existing}

    # Find new plant files
    if args.file:
        input_files = [SCRIPT_DIR / args.file]
    else:
        input_files = sorted(SCRIPT_DIR.glob("new_plants_*.json"))

    if not input_files:
        print("No new_plants_*.json files found in scripts/")
        sys.exit(0)

    # Load all new plants
    new_plants = []
    for fpath in input_files:
        if not fpath.exists():
            print(f"  Warning: {fpath} not found, skipping")
            continue
        with open(fpath, "r") as f:
            data = json.load(f)
        print(f"  {fpath.name}: {len(data)} species")
        new_plants.extend(data)

    # Deduplicate new plants against existing AND against each other
    seen = set(existing_names)
    unique_new = []
    for plant in new_plants:
        name = plant.get("Plant_Name_Latin", "")
        if name and name not in seen:
            seen.add(name)
            unique_new.append(plant)

    dupes = len(new_plants) - len(unique_new)
    print(f"\nNew species to add: {len(unique_new)} (removed {dupes} duplicates)")

    if not unique_new:
        print("Nothing to merge.")
        sys.exit(0)

    if args.preview:
        print(f"\nPreview — would add {len(unique_new)} species:")
        for p in sorted(unique_new, key=lambda x: x["Plant_Name_Latin"]):
            print(f"  {p['Plant_Name_Latin']:45s} ({p.get('Plant_Name_Common', ''):30s}) — {p.get('Plant_Family', '')}")
        print(f"\nTotal would be: {len(existing) + len(unique_new)} species")
        sys.exit(0)

    # Backup existing
    if not args.no_backup:
        backup_name = f"Plants.json.backup.{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        backup_path = SCRIPT_DIR / backup_name
        shutil.copy2(PLANTS_JSON, backup_path)
        print(f"\nBackup saved: {backup_path}")

    # Merge and sort
    merged = existing + unique_new
    merged.sort(key=lambda x: x.get("Plant_Name_Latin", ""))

    # Write
    with open(PLANTS_JSON, "w") as f:
        json.dump(merged, f, indent=2, ensure_ascii=False)
    print(f"\nMerged Plants.json: {len(merged)} species")

    # Validate
    with open(PLANTS_JSON, "r") as f:
        validated = json.loads(f.read())
    print(f"JSON validation passed ({len(validated)} entries)")

    # Show family distribution
    families = {}
    for p in merged:
        fam = p.get("Plant_Family", "Unknown")
        families[fam] = families.get(fam, 0) + 1
    print(f"\nFamily coverage: {len(families)} families")
    top_families = sorted(families.items(), key=lambda x: -x[1])[:15]
    for fam, count in top_families:
        print(f"  {fam:25s}: {count:4d} species")


if __name__ == "__main__":
    main()
