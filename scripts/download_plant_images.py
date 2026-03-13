#!/usr/bin/env python3
"""
Download medium-quality images for all plant species in Plants.json.

Reads pre-baked iNaturalist URLs from Plants.json and downloads the best
available image for each species. Images are saved to RadicleBotany/PlantImages/.

Each file is named by sanitized scientific name: "Abies amabilis" → "Abies_amabilis.jpg"

These images are bundled with the app so every plant has an instant image
without needing network access. The app can still upgrade to higher resolution
from the network when viewing individual species.

Size estimate: ~2,300 files × ~26KB = ~60MB

Usage:
    cd RadicleBotanyIOS
    python3 scripts/download_plant_images.py

    # Re-compress existing files to reduce bundle size:
    python3 scripts/download_plant_images.py --compress

    # Force re-download all (ignore existing files):
    python3 scripts/download_plant_images.py --force
"""

from __future__ import annotations

import json
import os
import sys
import time
import argparse
from io import BytesIO
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import Optional

try:
    from PIL import Image as PILImage
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

import urllib.request
import urllib.error

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(SCRIPT_DIR)
PLANTS_JSON = os.path.join(PROJECT_ROOT, "RadicleBotany", "Plants.json")
OUTPUT_DIR = os.path.join(PROJECT_ROOT, "RadicleBotany", "PlantImages")

# Target size: iNaturalist "small" = 240px longest side (~15-30KB)
# Good balance: instant loading, recognizable at hero size, reasonable bundle size
TARGET_SIZE = "small"  # Options: "square" (75px), "small" (240px), "medium" (500px)

# Image URL fields in priority order (same as Plant.bestImageURL in Swift)
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
    return name.replace(" ", "_").replace("/", "_").replace("'", "").replace('"', '')


def get_best_image_url(plant: dict) -> str | None:
    """Get the best image URL for a plant, converting to target size."""
    for field in IMAGE_FIELDS:
        url = plant.get(field)
        if url and isinstance(url, str) and url.strip():
            # Convert iNaturalist URL to target size
            if "/medium." in url:
                return url.replace("/medium.", f"/{TARGET_SIZE}.")
            elif "/square." in url:
                return url.replace("/square.", f"/{TARGET_SIZE}.")
            elif "/small." in url:
                return url.replace("/small.", f"/{TARGET_SIZE}.")
            elif "/large." in url:
                return url.replace("/large.", f"/{TARGET_SIZE}.")
            elif "/original." in url:
                return url.replace("/original.", f"/{TARGET_SIZE}.")
            # Non-iNaturalist URL, use as-is
            return url
    return None


def download_one(name: str, url: str, output_path: str, force: bool = False):
    """Download a single image. Returns (name, success, message, bytes)."""
    if not force and os.path.exists(output_path):
        size = os.path.getsize(output_path)
        return (name, True, "already exists", size)

    try:
        req = urllib.request.Request(url, headers={"User-Agent": "RadicleBotany/2.0"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            data = resp.read()
            if len(data) < 500:  # Too small to be a real image
                return (name, False, f"too small ({len(data)} bytes)", 0)
            with open(output_path, "wb") as f:
                f.write(data)
            return (name, True, f"{len(data):,} bytes", len(data))
    except urllib.error.HTTPError as e:
        return (name, False, f"HTTP {e.code}", 0)
    except Exception as e:
        return (name, False, str(e)[:80], 0)


def compress_images(output_dir: str, quality: int = 70, max_size: int = 240):
    """Re-compress all images in output directory to reduce size."""
    if not HAS_PIL:
        print("ERROR: Pillow is required for compression. Install with: pip3 install Pillow")
        sys.exit(1)

    files = [f for f in os.listdir(output_dir) if f.endswith(".jpg")]
    print(f"Compressing {len(files)} images (quality={quality}, max_size={max_size}px)...")

    original_total = 0
    compressed_total = 0
    for i, filename in enumerate(files, 1):
        path = os.path.join(output_dir, filename)
        original_size = os.path.getsize(path)
        original_total += original_size

        try:
            img = PILImage.open(path)
            # Resize if larger than max_size
            if max(img.size) > max_size:
                img.thumbnail((max_size, max_size), PILImage.LANCZOS)
            # Re-save with compression
            buf = BytesIO()
            img.save(buf, format="JPEG", quality=quality, optimize=True)
            compressed = buf.getvalue()
            compressed_total += len(compressed)

            # Only save if smaller
            if len(compressed) < original_size:
                with open(path, "wb") as f:
                    f.write(compressed)
        except Exception as e:
            compressed_total += original_size
            if i % 500 == 0:
                print(f"  Warning: {filename}: {e}")

        if i % 500 == 0:
            print(f"  Progress: {i}/{len(files)}")

    savings = original_total - compressed_total
    print(f"\nCompression complete:")
    print(f"  Original: {original_total / 1024 / 1024:.1f} MB")
    print(f"  Compressed: {compressed_total / 1024 / 1024:.1f} MB")
    print(f"  Saved: {savings / 1024 / 1024:.1f} MB ({savings / original_total * 100:.1f}%)")


def main():
    parser = argparse.ArgumentParser(description="Download plant images for bundling")
    parser.add_argument("--force", action="store_true", help="Re-download all images")
    parser.add_argument("--compress", action="store_true", help="Re-compress existing images")
    parser.add_argument("--workers", type=int, default=20, help="Concurrent downloads (default: 20)")
    args = parser.parse_args()

    # Compress mode
    if args.compress:
        compress_images(OUTPUT_DIR)
        return

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
        url = get_best_image_url(plant)
        if not url:
            no_url_count += 1
            continue
        filename = sanitize_filename(name) + ".jpg"
        output_path = os.path.join(OUTPUT_DIR, filename)
        tasks.append((name, url, output_path))

    print(f"Target size: {TARGET_SIZE} (~240px)")
    print(f"Downloading {len(tasks)} images ({no_url_count} species have no URL)")
    print(f"Output: {OUTPUT_DIR}")
    if args.force:
        print("Force mode: re-downloading all images")
    print()

    # Download with thread pool
    success_count = 0
    fail_count = 0
    skip_count = 0
    total_bytes = 0
    failed_species = []
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures = {
            pool.submit(download_one, name, url, path, args.force): name
            for name, url, path in tasks
        }

        for i, future in enumerate(as_completed(futures), 1):
            name, ok, msg, size = future.result()
            total_bytes += size
            if ok:
                if "already exists" in msg:
                    skip_count += 1
                else:
                    success_count += 1
            else:
                fail_count += 1
                failed_species.append(f"{name}: {msg}")
                if fail_count <= 20:
                    print(f"  FAIL: {name} — {msg}")

            if i % 200 == 0:
                elapsed = time.time() - start_time
                rate = i / elapsed
                eta = (len(tasks) - i) / rate
                print(f"  Progress: {i}/{len(tasks)} ({elapsed:.1f}s, ETA: {eta:.0f}s)")

    # Calculate actual disk size
    actual_size = sum(
        os.path.getsize(os.path.join(OUTPUT_DIR, f))
        for f in os.listdir(OUTPUT_DIR)
        if f.endswith(".jpg")
    )

    elapsed = time.time() - start_time
    print()
    print(f"Done in {elapsed:.1f}s")
    print(f"  Downloaded: {success_count}")
    print(f"  Skipped (already existed): {skip_count}")
    print(f"  Failed: {fail_count}")
    print(f"  Total images on disk: {len([f for f in os.listdir(OUTPUT_DIR) if f.endswith('.jpg')])}")
    print(f"  Total size: {actual_size / 1024 / 1024:.1f} MB")

    if failed_species:
        # Save failed list
        failed_path = os.path.join(SCRIPT_DIR, "failed_downloads.txt")
        with open(failed_path, "w") as f:
            f.write("\n".join(failed_species))
        print(f"\n  Failed species list saved to: {failed_path}")

    print(f"\nNext steps:")
    print(f"  1. Add RadicleBotany/PlantImages/ folder to Xcode project as a folder reference")
    print(f"  2. Build and run — images load instantly from bundle")
    if HAS_PIL:
        print(f"  3. Optional: python3 scripts/download_plant_images.py --compress")


if __name__ == "__main__":
    main()
