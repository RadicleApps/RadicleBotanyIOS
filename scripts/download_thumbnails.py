#!/usr/bin/env python3
"""
Download 75×75 square thumbnails for all plant species in Plants.json.

Reads pre-baked iNaturalist URLs from Plants.json, converts /medium. → /square.
for small thumbnails, and downloads them to RadicleBotany/PlantThumbnails/.

Each file is named by sanitized scientific name: "Abies amabilis" → "Abies_amabilis.jpg"

Output: ~2,300 files, ~4KB each, ~9MB total — safe to bundle with the app.

Usage:
    cd RadicleBotanyIOS
    python3 scripts/download_thumbnails.py
"""

import json
import os
import sys
import urllib.request
import urllib.error
import hashlib
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
PLANTS_JSON = os.path.join(PROJECT_ROOT, "RadicleBotany", "Plants.json")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "RadicleBotany", "PlantThumbnails")

# Image URL fields in priority order (same as Plant.bestImageURL)
IMAGE_FIELDS = [
    "flower_image_url",
    "habit_image_url",
    "leaf_image_url",
    "image_url",
    "fruit_image_url",
    "bark_image_url",
    "stem_image_url",
]

def sanitize_filename(name: str) -> str:
    """Convert scientific name to safe filename: 'Abies amabilis' → 'Abies_amabilis'"""
    return name.replace(" ", "_").replace("/", "_").replace("'", "")

def get_thumbnail_url(plant: dict):
    """Get the best thumbnail URL for a plant (75×75 square from iNaturalist)."""
    for field in IMAGE_FIELDS:
        url = plant.get(field)
        if url and isinstance(url, str) and url.strip():
            # Convert iNaturalist medium → square for 75×75 thumbnail
            if "/medium." in url:
                return url.replace("/medium.", "/square.")
            return url
    return None

def download_one(name, url, output_path):
    """Download a single thumbnail. Returns (name, success, message)."""
    if os.path.exists(output_path):
        return (name, True, "already exists")

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RadicleBotany/2.0"})
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = resp.read()
            if len(data) < 100:  # Too small to be a real image
                return (name, False, f"too small ({len(data)} bytes)")
            with open(output_path, "wb") as f:
                f.write(data)
            return (name, True, f"{len(data)} bytes")
    except Exception as e:
        return (name, False, str(e))

def main():
    # Load Plants.json
    with open(PLANTS_JSON, "r") as f:
        plants = json.load(f)
    print(f"Loaded {len(plants)} plants from Plants.json")

    # Create output directory
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # Build download tasks
    tasks = []
    no_url_count = 0
    for plant in plants:
        name = plant.get("Plant_Name_Latin", "").strip()
        if not name:
            continue
        url = get_thumbnail_url(plant)
        if not url:
            no_url_count += 1
            continue
        filename = sanitize_filename(name) + ".jpg"
        output_path = os.path.join(OUTPUT_DIR, filename)
        tasks.append((name, url, output_path))

    print(f"Downloading {len(tasks)} thumbnails ({no_url_count} species have no URL)")
    print(f"Output: {OUTPUT_DIR}")
    print()

    # Download with thread pool (20 concurrent)
    success_count = 0
    fail_count = 0
    skip_count = 0
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=20) as pool:
        futures = {
            pool.submit(download_one, name, url, path): name
            for name, url, path in tasks
        }

        for i, future in enumerate(as_completed(futures), 1):
            name, ok, msg = future.result()
            if ok:
                if "already exists" in msg:
                    skip_count += 1
                else:
                    success_count += 1
            else:
                fail_count += 1
                print(f"  FAIL: {name} — {msg}")

            if i % 200 == 0:
                elapsed = time.time() - start_time
                print(f"  Progress: {i}/{len(tasks)} ({elapsed:.1f}s)")

    elapsed = time.time() - start_time
    total_size = sum(
        os.path.getsize(os.path.join(OUTPUT_DIR, f))
        for f in os.listdir(OUTPUT_DIR)
        if f.endswith(".jpg")
    )

    print()
    print(f"Done in {elapsed:.1f}s")
    print(f"  Downloaded: {success_count}")
    print(f"  Skipped (already existed): {skip_count}")
    print(f"  Failed: {fail_count}")
    print(f"  Total size: {total_size / 1024 / 1024:.1f} MB")

if __name__ == "__main__":
    main()
