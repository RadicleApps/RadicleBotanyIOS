#!/usr/bin/env python3
"""
Merge color illustration PNG URLs from CSV into Botany.json.

Reads the CSV with columns: Term, Image/PNG|Illustration URL
Matches terms by name (case-insensitive) and adds colorImageURL field.
"""

import csv
import json
import sys
from pathlib import Path

def main():
    csv_path = Path.home() / "Downloads" / "🟢 Botany.csv"
    botany_json_path = Path(__file__).parent.parent / "RadicleBotany" / "Botany.json"

    # Also update the root-level copy
    root_json_path = Path(__file__).parent.parent / "RadicleBotany_Botany.json"

    # Read CSV
    color_urls = {}
    with open(csv_path, 'r', encoding='utf-8') as f:
        reader = csv.reader(f)
        header = next(reader)  # Skip header
        for row in reader:
            if len(row) >= 2:
                term = row[0].strip()
                url = row[1].strip()
                if term and url:
                    color_urls[term.lower()] = url

    print(f"Read {len(color_urls)} color image URLs from CSV")

    # Read Botany.json
    with open(botany_json_path, 'r', encoding='utf-8') as f:
        terms = json.load(f)

    print(f"Read {len(terms)} terms from Botany.json")

    # Merge
    matched = 0
    for term_obj in terms:
        term_name = term_obj['term'].strip().lower()
        if term_name in color_urls:
            term_obj['colorImageURL'] = color_urls[term_name]
            matched += 1
        else:
            # Ensure field exists as null for clean JSON
            if 'colorImageURL' not in term_obj:
                term_obj['colorImageURL'] = None

    print(f"Matched {matched} terms with color images")

    # Write back
    with open(botany_json_path, 'w', encoding='utf-8') as f:
        json.dump(terms, f, indent=2, ensure_ascii=False)

    print(f"Written updated Botany.json")

    # Also update root copy if it exists
    if root_json_path.exists():
        with open(root_json_path, 'w', encoding='utf-8') as f:
            json.dump(terms, f, indent=2, ensure_ascii=False)
        print(f"Written updated RadicleBotany_Botany.json")

if __name__ == '__main__':
    main()
