#!/usr/bin/env python3
"""
Pre-bake iNaturalist image URLs into Plants.json.

Fetches image URLs for all species that don't already have them,
so the iOS app doesn't need to make these API calls on first launch.

Usage:
    python3 scripts/enrich_inat_images.py

Rate limits: iNaturalist allows ~100 requests/minute.
We use 2 requests per species (search + detail) with batching.
For ~2,132 species, expect ~45 minutes.

Progress is saved incrementally — safe to interrupt and resume.
"""

import json
import time
import sys
import os
import urllib.request
import urllib.parse
import urllib.error

PLANTS_JSON = os.path.join(os.path.dirname(__file__), '..', 'RadicleBotany', 'Plants.json')

# Organ assignment order (matches iOS PlantImageService logic)
ORGAN_KEYS = [
    'flower_image_url',
    'leaf_image_url',
    'fruit_image_url',
    'bark_image_url',
    'habit_image_url',
    'stem_image_url',
]

def fetch_json(url, timeout=15):
    """Fetch JSON from a URL with error handling."""
    req = urllib.request.Request(url, headers={
        'User-Agent': 'RadicleBotany/1.0 (iOS; educational botany app; image pre-baking)',
        'Accept': 'application/json',
    })
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            if resp.status != 200:
                return None
            return json.loads(resp.read().decode('utf-8'))
    except (urllib.error.URLError, urllib.error.HTTPError, json.JSONDecodeError, TimeoutError) as e:
        return None


def fetch_inat_images(scientific_name):
    """
    Fetch image URLs from iNaturalist for a species.
    Returns (general_url, {organ_key: url}) or (None, {}) on failure.
    """
    # Step 1: Search for the taxon
    params = urllib.parse.urlencode({
        'q': scientific_name,
        'rank': 'species',
        'per_page': '1',
        'locale': 'en',
    })
    search_url = f'https://api.inaturalist.org/v1/taxa?{params}'
    search_data = fetch_json(search_url)

    if not search_data or not search_data.get('results'):
        return None, {}

    taxon = search_data['results'][0]
    taxon_id = taxon.get('id')
    if not taxon_id:
        return None, {}

    # Quick check: does the search result name match?
    result_name = taxon.get('name', '').lower()
    query_name = scientific_name.lower()
    if result_name != query_name:
        # Allow genus match (first word)
        if result_name.split()[0] != query_name.split()[0]:
            return None, {}

    # Get the default photo as the general image
    default_photo = taxon.get('default_photo', {})
    general_url = None
    if default_photo:
        general_url = default_photo.get('medium_url')

    # Step 2: Fetch detailed taxon to get taxon_photos array
    detail_url = f'https://api.inaturalist.org/v1/taxa/{taxon_id}'
    detail_data = fetch_json(detail_url)

    organ_urls = {}
    if detail_data and detail_data.get('results'):
        detail = detail_data['results'][0]
        taxon_photos = detail.get('taxon_photos', [])

        # If no general URL from default_photo, use first taxon_photo
        if not general_url and taxon_photos:
            first_photo = taxon_photos[0].get('photo', {})
            general_url = first_photo.get('medium_url')

        # Assign photos sequentially to organ slots (iNaturalist photos are NOT organ-tagged)
        for i, tp in enumerate(taxon_photos[1:7]):  # Skip first (used as general), take up to 6
            photo = tp.get('photo', {})
            url = photo.get('medium_url')
            if url and i < len(ORGAN_KEYS):
                organ_urls[ORGAN_KEYS[i]] = url

    return general_url, organ_urls


def main():
    # Load Plants.json
    plants_path = os.path.abspath(PLANTS_JSON)
    if not os.path.exists(plants_path):
        print(f'Error: {plants_path} not found')
        sys.exit(1)

    with open(plants_path, 'r') as f:
        plants = json.load(f)

    total = len(plants)
    needs_images = [i for i, p in enumerate(plants) if not p.get('image_url')]
    already_has = total - len(needs_images)

    print(f'Total species: {total}')
    print(f'Already have images: {already_has}')
    print(f'Need images: {len(needs_images)}')
    print()

    if not needs_images:
        print('All species already have image URLs. Nothing to do.')
        return

    success = 0
    failed = 0
    start_time = time.time()
    save_interval = 25  # Save every 25 species

    for batch_num, idx in enumerate(needs_images):
        plant = plants[idx]
        name = plant.get('Plant_Name_Latin', 'Unknown')

        # Progress
        progress = batch_num + 1
        pct = progress / len(needs_images) * 100
        elapsed = time.time() - start_time
        rate = progress / elapsed if elapsed > 0 else 0
        eta = (len(needs_images) - progress) / rate if rate > 0 else 0

        print(f'[{progress}/{len(needs_images)}] ({pct:.1f}%) {name}', end=' ... ', flush=True)

        general_url, organ_urls = fetch_inat_images(name)

        if general_url:
            plant['image_url'] = general_url
            for key, url in organ_urls.items():
                plant[key] = url
            organ_count = len(organ_urls)
            success += 1
            print(f'OK (+{organ_count} organs)')
        else:
            failed += 1
            print('MISS')

        # Rate limit: ~1.2s between species (2 requests × 0.6s = fits in ~100 req/min)
        time.sleep(0.6)

        # Save incrementally
        if progress % save_interval == 0 or progress == len(needs_images):
            with open(plants_path, 'w') as f:
                json.dump(plants, f, indent=2, ensure_ascii=False)
            print(f'  [saved] {success} enriched, {failed} missed | ETA: {eta/60:.1f} min')

    # Final save
    with open(plants_path, 'w') as f:
        json.dump(plants, f, indent=2, ensure_ascii=False)

    elapsed = time.time() - start_time
    print()
    print(f'Done in {elapsed/60:.1f} minutes')
    print(f'  Success: {success}/{len(needs_images)} ({success/len(needs_images)*100:.1f}%)')
    print(f'  Failed: {failed}')
    print(f'  Total with images now: {already_has + success}/{total}')


if __name__ == '__main__':
    main()
