#!/usr/bin/env python3
"""
Export image URLs for all plant species and bake them into Plants.json.

Two-phase approach:
  Phase 1: Read existing URLs from the simulator's SwiftData SQLite database.
  Phase 2: For species missing URLs, fetch from iNaturalist API directly.

The result is a Plants.json with image_url, flower_image_url, leaf_image_url, etc.
fields so the iOS app can display images instantly on first launch without
making thousands of API calls.

Usage:
    python3 scripts/export_image_urls.py

    # Resume after interruption (uses checkpoint file automatically):
    python3 scripts/export_image_urls.py

    # Force re-fetch all (ignores checkpoint):
    python3 scripts/export_image_urls.py --fresh

    # Only export from simulator DB (no iNaturalist API calls):
    python3 scripts/export_image_urls.py --db-only
"""

import json
import os
import sqlite3
import sys
import time
import urllib.request
import urllib.parse
import argparse
from pathlib import Path
from typing import Optional, Dict

# ── Paths ──────────────────────────────────────────────────────────────────

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
PLANTS_JSON = PROJECT_DIR / "RadicleBotany" / "Plants.json"
CHECKPOINT_FILE = SCRIPT_DIR / ".image_url_checkpoint.json"

# Simulator DB with 2,311 plants (most recent)
SIMULATOR_DB = Path.home() / (
    "Library/Developer/CoreSimulator/Devices/"
    "D8085CE9-B5E8-43D2-A9A0-6B87C810DABF/data/Containers/Data/Application/"
    "8357FD46-AED1-4479-8F7E-059A7AF2554A/Library/Application Support/default.store"
)

# ── iNaturalist API ────────────────────────────────────────────────────────

INAT_SEARCH_URL = "https://api.inaturalist.org/v1/taxa"
INAT_DETAIL_URL = "https://api.inaturalist.org/v1/taxa/{taxon_id}"
USER_AGENT = "RadicleBotany/1.0 (iOS; educational botany app; image-prebake)"
REQUEST_DELAY = 0.65  # seconds between API calls (~92 req/min, under 100 limit)


def inat_request(url: str) -> Optional[dict]:
    """Make a GET request to iNaturalist with proper headers and error handling."""
    req = urllib.request.Request(url)
    req.add_header("User-Agent", USER_AGENT)
    req.add_header("Accept", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status == 200:
                return json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        print(f"    ⚠️  Request failed: {e}")
    return None


def fetch_inat_images(scientific_name: str) -> dict:
    """
    Fetch image URLs from iNaturalist for a species.
    Returns dict with image_url, flower_image_url, leaf_image_url, etc.
    Mirrors the iOS PlantImageService 3-tier logic (Tier 1: iNaturalist).
    """
    result = {}

    # Step 1: Search for the taxon
    params = urllib.parse.urlencode({
        "q": scientific_name,
        "rank": "species",
        "per_page": "1",
        "locale": "en",
    })
    search_url = f"{INAT_SEARCH_URL}?{params}"
    search_data = inat_request(search_url)
    time.sleep(REQUEST_DELAY)

    if not search_data or not search_data.get("results"):
        return result

    taxon = search_data["results"][0]
    # Verify exact name match (case-insensitive)
    if taxon.get("name", "").lower() != scientific_name.lower():
        return result

    # Get default photo from search result
    default_photo = taxon.get("default_photo")
    if default_photo:
        url = default_photo.get("medium_url") or default_photo.get("square_url")
        if url:
            result["image_url"] = url.replace("/square.", "/medium.")

    # Step 2: Fetch detail to get taxon_photos array
    taxon_id = taxon["id"]
    detail_url = INAT_DETAIL_URL.format(taxon_id=taxon_id)
    detail_data = inat_request(detail_url)
    time.sleep(REQUEST_DELAY)

    if not detail_data or not detail_data.get("results"):
        return result

    full_taxon = detail_data["results"][0]
    taxon_photos = full_taxon.get("taxon_photos", [])

    if not taxon_photos:
        return result

    # First photo as general image
    first_photo = taxon_photos[0].get("photo", {})
    url = first_photo.get("medium_url") or first_photo.get("square_url")
    if url:
        result["image_url"] = url.replace("/square.", "/medium.")

    # Assign additional photos to organ slots (same sequential mapping as iOS)
    organ_keys = [
        "flower_image_url",
        "leaf_image_url",
        "fruit_image_url",
        "bark_image_url",
        "habit_image_url",
        "stem_image_url",
    ]
    for i, key in enumerate(organ_keys):
        photo_index = i + 1
        if photo_index >= len(taxon_photos):
            break
        photo = taxon_photos[photo_index].get("photo", {})
        url = photo.get("medium_url") or photo.get("square_url")
        if url:
            result[key] = url.replace("/square.", "/medium.")

    return result


# ── Simulator DB Export ────────────────────────────────────────────────────

def export_from_simulator_db() -> dict:
    """
    Read image URLs from the simulator's SwiftData SQLite database.
    Returns dict mapping scientific_name -> {image_url, flower_image_url, ...}
    """
    if not SIMULATOR_DB.exists():
        print(f"⚠️  Simulator DB not found at: {SIMULATOR_DB}")
        return {}

    db_urls = {}
    conn = sqlite3.connect(str(SIMULATOR_DB))
    cursor = conn.cursor()

    cursor.execute("""
        SELECT
            ZSCIENTIFICNAME,
            ZIMAGEURL,
            ZFLOWERIMAGEURL,
            ZLEAFIMAGEURL,
            ZFRUITIMAGEURL,
            ZBARKIMAGEURL,
            ZSTEMIMAGEURL,
            ZHABITIMAGEURL,
            ZGBIFID
        FROM ZPLANT
        WHERE ZIMAGEURL IS NOT NULL AND ZIMAGEURL != ''
    """)

    for row in cursor.fetchall():
        name = row[0]
        urls = {}
        if row[1]:
            urls["image_url"] = row[1]
        if row[2]:
            urls["flower_image_url"] = row[2]
        if row[3]:
            urls["leaf_image_url"] = row[3]
        if row[4]:
            urls["fruit_image_url"] = row[4]
        if row[5]:
            urls["bark_image_url"] = row[5]
        if row[6]:
            urls["stem_image_url"] = row[6]
        if row[7]:
            urls["habit_image_url"] = row[7]
        if row[8]:
            urls["gbif_id"] = row[8]
        if urls:
            db_urls[name] = urls

    conn.close()
    return db_urls


# ── Checkpoint Management ──────────────────────────────────────────────────

def load_checkpoint() -> dict:
    """Load progress from checkpoint file."""
    if CHECKPOINT_FILE.exists():
        with open(CHECKPOINT_FILE, "r") as f:
            return json.load(f)
    return {}


def save_checkpoint(data: dict):
    """Save progress to checkpoint file."""
    with open(CHECKPOINT_FILE, "w") as f:
        json.dump(data, f)


# ── Main ───────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Pre-bake image URLs into Plants.json")
    parser.add_argument("--fresh", action="store_true", help="Ignore checkpoint, re-fetch all")
    parser.add_argument("--db-only", action="store_true", help="Only export from simulator DB, no API calls")
    args = parser.parse_args()

    # 1. Load Plants.json
    print(f"📂 Loading Plants.json from: {PLANTS_JSON}")
    with open(PLANTS_JSON, "r") as f:
        plants = json.load(f)
    print(f"   Found {len(plants)} species")

    # 2. Export from simulator DB
    print(f"\n📱 Reading simulator database...")
    db_urls = export_from_simulator_db()
    print(f"   Found URLs for {len(db_urls)} species from simulator")

    # 3. Load checkpoint (or start fresh)
    if args.fresh:
        checkpoint = {}
        print("\n🔄 Fresh mode — ignoring checkpoint")
    else:
        checkpoint = load_checkpoint()
        if checkpoint:
            print(f"\n📋 Loaded checkpoint with {len(checkpoint)} cached results")

    # 4. Merge DB URLs into checkpoint
    for name, urls in db_urls.items():
        if name not in checkpoint:
            checkpoint[name] = urls

    # 5. Identify species that still need fetching
    all_names = [p["Plant_Name_Latin"] for p in plants]
    needs_fetch = [n for n in all_names if n not in checkpoint]

    print(f"\n📊 Status:")
    print(f"   Total species:       {len(all_names)}")
    print(f"   Already have URLs:   {len(all_names) - len(needs_fetch)}")
    print(f"   Need iNat fetch:     {len(needs_fetch)}")

    if args.db_only:
        print("\n⏭️  --db-only mode, skipping iNaturalist API calls")
    elif needs_fetch:
        print(f"\n🌐 Fetching from iNaturalist ({len(needs_fetch)} species)...")
        print(f"   Estimated time: ~{len(needs_fetch) * 1.3 / 60:.0f} minutes")
        print(f"   (Progress saved every 10 species — safe to interrupt with Ctrl+C)\n")

        fetched = 0
        found = 0
        for i, name in enumerate(needs_fetch, 1):
            print(f"   [{i}/{len(needs_fetch)}] {name}...", end=" ", flush=True)

            try:
                urls = fetch_inat_images(name)
                if urls:
                    checkpoint[name] = urls
                    found += 1
                    print(f"✅ ({len(urls)} URLs)")
                else:
                    # Mark as checked but empty so we don't retry
                    checkpoint[name] = {"_no_image": True}
                    print("❌ no match")

                fetched += 1

                # Save checkpoint every 10 species
                if fetched % 10 == 0:
                    save_checkpoint(checkpoint)

            except KeyboardInterrupt:
                print("\n\n⏸️  Interrupted — saving checkpoint...")
                save_checkpoint(checkpoint)
                print(f"   Saved {len(checkpoint)} results. Run again to resume.")
                sys.exit(0)
            except Exception as e:
                print(f"⚠️  error: {e}")
                checkpoint[name] = {"_error": str(e)}

        save_checkpoint(checkpoint)
        print(f"\n   Fetched: {fetched}, Found images: {found}, No match: {fetched - found}")

    # 6. Merge URLs into Plants.json
    print(f"\n📝 Merging URLs into Plants.json...")
    enriched = 0
    url_keys = [
        "image_url", "flower_image_url", "leaf_image_url",
        "fruit_image_url", "bark_image_url", "stem_image_url",
        "habit_image_url", "gbif_id",
    ]

    for plant in plants:
        name = plant["Plant_Name_Latin"]
        if name in checkpoint:
            urls = checkpoint[name]
            if urls.get("_no_image") or urls.get("_error"):
                continue
            has_any = False
            for key in url_keys:
                if key in urls:
                    plant[key] = urls[key]
                    has_any = True
            if has_any:
                enriched += 1

    # Ensure all plants have the URL keys (null for those without)
    for plant in plants:
        for key in url_keys:
            if key not in plant:
                plant[key] = None

    print(f"   Enriched {enriched} of {len(plants)} species with image URLs")

    # 7. Write enriched Plants.json
    # Backup first
    backup_path = PLANTS_JSON.with_suffix(".json.bak")
    print(f"\n💾 Backing up original to: {backup_path.name}")
    with open(backup_path, "w") as f:
        json.dump(json.loads(PLANTS_JSON.read_text()), f, indent=2, ensure_ascii=False)

    print(f"💾 Writing enriched Plants.json...")
    with open(PLANTS_JSON, "w") as f:
        json.dump(plants, f, indent=2, ensure_ascii=False)

    new_size = PLANTS_JSON.stat().st_size
    print(f"   New size: {new_size / 1024 / 1024:.1f} MB")

    # 8. Summary
    has_image = sum(1 for p in plants if p.get("image_url"))
    has_flower = sum(1 for p in plants if p.get("flower_image_url"))
    has_leaf = sum(1 for p in plants if p.get("leaf_image_url"))

    print(f"\n✅ Done!")
    print(f"   Species with image_url:        {has_image} / {len(plants)}")
    print(f"   Species with flower_image_url:  {has_flower} / {len(plants)}")
    print(f"   Species with leaf_image_url:    {has_leaf} / {len(plants)}")
    print(f"\n   Next: rebuild the iOS app — images will load instantly from JSON.")

    # Clean up checkpoint on full completion
    if not needs_fetch or args.db_only:
        if CHECKPOINT_FILE.exists():
            CHECKPOINT_FILE.unlink()
            print("   Cleaned up checkpoint file.")


if __name__ == "__main__":
    main()
