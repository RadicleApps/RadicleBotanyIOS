#!/usr/bin/env python3
"""
expand_plants.py — Expand RadicleBotany Plants.json with new species.

Pipeline:
  1. GBIF Occurrence API → discover species by region (bounding box)
  2. GBIF Species API → get full taxonomy (kingdom, class, order, family, genus)
  3. Deduplicate against existing Plants.json
  4. OpenAI GPT-4o → generate trait fields from controlled vocabulary
  5. Output Plants.json-compatible JSON

Usage:
  python expand_plants.py --region northeast --dry-run
  python expand_plants.py --region northeast --limit 50
  python expand_plants.py --region northeast

Environment variables:
  OPENAI_API_KEY  — OpenAI API key (only needed for full run, not dry-run)
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Dict, List, Optional, Set

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REGIONS = {
    "northeast": {
        "name": "Northeast US",
        "min_lat": 37.0, "max_lat": 47.0,
        "min_lon": -80.0, "max_lon": -67.0,
    },
    "southeast": {
        "name": "Southeast US",
        "min_lat": 24.5, "max_lat": 37.0,
        "min_lon": -91.0, "max_lon": -75.0,
    },
    "midwest": {
        "name": "Midwest US",
        "min_lat": 36.0, "max_lat": 49.0,
        "min_lon": -104.0, "max_lon": -80.0,
    },
    "greatplains": {
        "name": "Great Plains",
        "min_lat": 30.0, "max_lat": 49.0,
        "min_lon": -110.0, "max_lon": -95.0,
    },
    "rockies": {
        "name": "Rocky Mountains",
        "min_lat": 31.0, "max_lat": 49.0,
        "min_lon": -117.0, "max_lon": -104.0,
    },
    "pacificnw": {
        "name": "Pacific Northwest",
        "min_lat": 42.0, "max_lat": 49.0,
        "min_lon": -125.0, "max_lon": -116.0,
    },
    "california": {
        "name": "California",
        "min_lat": 32.5, "max_lat": 42.0,
        "min_lon": -124.5, "max_lon": -114.0,
    },
    "southwest": {
        "name": "Southwest US",
        "min_lat": 25.0, "max_lat": 37.0,
        "min_lon": -120.0, "max_lon": -103.0,
    },
}

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
PLANTS_JSON = PROJECT_DIR / "RadicleBotany" / "Plants.json"
VOCAB_JSON = SCRIPT_DIR / "trait_vocabulary.json"


# ---------------------------------------------------------------------------
# Step 1: GBIF Species Discovery
# ---------------------------------------------------------------------------

def fetch_gbif_species(region: dict, max_species: int = 500) -> List[dict]:
    """
    Discover plant species in a region using GBIF occurrence facets.

    Uses the facet=speciesKey approach to get unique species
    observed within the bounding box, sorted by occurrence count.
    """
    url = "https://api.gbif.org/v1/occurrence/search"
    params = {
        "decimalLatitude": f"{region['min_lat']},{region['max_lat']}",
        "decimalLongitude": f"{region['min_lon']},{region['max_lon']}",
        "taxonKey": 6,  # Plantae kingdom
        "hasCoordinate": "true",
        "limit": 0,  # We only want facets, not individual occurrences
        "facet": "speciesKey",
        "facetLimit": max_species,
    }

    print(f"  Querying GBIF for species in {region['name']}...")
    resp = requests.get(url, params=params, timeout=180)
    resp.raise_for_status()
    data = resp.json()

    print(f"  Total occurrence records: {data['count']:,}")

    # Extract species keys from facets
    species_keys = []
    for facet in data.get("facets", []):
        if facet["field"] == "SPECIES_KEY":
            for entry in facet["counts"]:
                species_keys.append({
                    "gbif_key": int(entry["name"]),
                    "occurrence_count": entry["count"],
                })

    print(f"  Found {len(species_keys)} unique species")
    return species_keys


# ---------------------------------------------------------------------------
# Step 2: GBIF Taxonomy Enrichment
# ---------------------------------------------------------------------------

def enrich_species(gbif_key: int) -> Optional[dict]:
    """Get full taxonomy + vernacular name from GBIF species API."""
    try:
        # Get taxonomy
        resp = requests.get(
            f"https://api.gbif.org/v1/species/{gbif_key}",
            timeout=15,
        )
        resp.raise_for_status()
        data = resp.json()

        # Skip non-species ranks (genus-level, subspecies, etc.)
        rank = data.get("rank", "")
        if rank not in ("SPECIES",):
            return None

        scientific_name = data.get("canonicalName", "")
        if not scientific_name:
            return None

        # Get vernacular (common) names
        common_name = ""
        try:
            vn_resp = requests.get(
                f"https://api.gbif.org/v1/species/{gbif_key}/vernacularNames",
                params={"limit": 20},
                timeout=10,
            )
            vn_resp.raise_for_status()
            vn_data = vn_resp.json()
            # Prefer English names
            for vn in vn_data.get("results", []):
                if vn.get("language", "").lower() in ("en", "eng", "english"):
                    common_name = vn.get("vernacularName", "")
                    break
            # Fallback: take any name
            if not common_name and vn_data.get("results"):
                common_name = vn_data["results"][0].get("vernacularName", "")
        except Exception:
            pass

        if not common_name:
            common_name = scientific_name  # Fallback to latin name

        return {
            "scientific_name": scientific_name,
            "common_name": common_name,
            "kingdom": data.get("kingdom", "Plantae"),
            "class": data.get("class", ""),
            "order": data.get("order", ""),
            "family": data.get("family", ""),
            "genus": data.get("genus", ""),
            "gbif_key": gbif_key,
        }
    except Exception as e:
        print(f"    GBIF enrichment failed for key {gbif_key}: {e}")
        return None


# ---------------------------------------------------------------------------
# Step 3: Deduplication
# ---------------------------------------------------------------------------

def load_existing_species() -> Set[str]:
    """Load scientific names from existing Plants.json."""
    if not PLANTS_JSON.exists():
        print(f"  Warning: {PLANTS_JSON} not found, no deduplication")
        return set()

    with open(PLANTS_JSON, "r") as f:
        plants = json.load(f)
    names = {p["Plant_Name_Latin"] for p in plants}
    print(f"  Loaded {len(names)} existing species from Plants.json")
    return names


# ---------------------------------------------------------------------------
# Step 4: OpenAI Trait Generation
# ---------------------------------------------------------------------------

def load_vocabulary() -> dict:
    """Load controlled trait vocabulary."""
    with open(VOCAB_JSON, "r") as f:
        return json.load(f)


def build_trait_prompt(species_batch: List[dict], vocabulary: dict) -> str:
    """Build a prompt for GPT to generate trait data for a batch of species."""

    # Only include categories that map to Plant model fields
    relevant_cats = {
        "Leaf_Type": "Leaf Type",
        "Leaf_Shape": "Leaf Shape",
        "Leaf_Arrangement": "Leaf Arrangement",
        "Leaf_Attachment": "Leaf Attachment",
        "Leaf_Margin": "Leaf Margin",
        "Leaf_Apex": "Leaf Apex",
        "Leaf_Base": "Leaf Base",
        "Leaf_Venation": "Leaf Venation",
        "Leaf_Texture": "Surface Texture",
        "Leaf_Stipules": "Stipule Arrangement",
        "Flower_Inflorescence": "Inflorescence Type",
        "Flower_Symmetry": "Floral Symmetry",
        "Flower_Petal Count": "Petal Count",
        "Flower_Petal Fusion": "Petal Fusion",
        "Flower_Sepal Presence": "Sepal Presence",
        "Flower_Sepal Fusion": "Sepal Fusion",
        "Flower_Color": "Petal Color",
        "Flower_Position": "Flower Position",
        "Flower_Ovary Position": "Ovary Position",
        "Flower_Sexuality": "Floral Sex",
        "Flower_Floral Part": "Floral Part",
        "Fruit_Type": "Fruit Type",
        "Fruit_Seed Trait": "Seed Trait",
        "Root_Type": "Root Type",
        "Environment_Habitat": "Habitat",
        "Environment_Growth Habit": "Annual/Biennial",
    }

    vocab_lines = []
    for field, cat in relevant_cats.items():
        options = vocabulary.get(cat, [])
        if options:
            vocab_lines.append(f'  "{field}": {json.dumps(options)}')
    vocab_block = "{\n" + ",\n".join(vocab_lines) + "\n}"

    species_lines = []
    for sp in species_batch:
        species_lines.append(
            f"  - {sp['scientific_name']} (Common: {sp['common_name']}, "
            f"Family: {sp['family']}, Order: {sp['order']}, Class: {sp['class']})"
        )

    return f"""You are a botanical expert. For each species below, provide trait values for a plant morphology database.

SPECIES:
{chr(10).join(species_lines)}

CONTROLLED VOCABULARY — you MUST pick values ONLY from these lists:
{vocab_block}

FREE-TEXT FIELDS (not constrained to a list):
  "Stem_Habit": one of [Erect, Decumbent, Procumbent, Prostrate, Ascending, Climbing, Trailing, Scandent]
  "Stem_Structure": one of [Woody, Herbaceous, Semi-woody]
  "Stem_Branching": one of [Alternate, Opposite, Whorled, Dichotomous, Sparingly branched]
  "Environment_Soil": short text like "Well-drained, acidic" or "Moist, loamy"
  "Bloom_Months": comma-separated month numbers 1-12 (e.g. "4,5,6" for April-June)
  "Fruit_Months": comma-separated month numbers 1-12 or null

Return a JSON object with key "species" containing an array. Each element has:
  "scientific_name": the latin binomial
  ...all trait fields listed above...

If a trait is truly inapplicable (e.g. flower traits for a fern), use null.
Do NOT invent values outside the controlled vocabulary lists.
Return ONLY valid JSON, no markdown fences or commentary."""


def generate_traits_batch(species_batch: List[dict], vocabulary: dict, client) -> List[dict]:
    """Call OpenAI to generate traits for a batch of species."""
    prompt = build_trait_prompt(species_batch, vocabulary)

    response = client.chat.completions.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You are a precise botanical data entry specialist. Return only valid JSON."},
            {"role": "user", "content": prompt},
        ],
        response_format={"type": "json_object"},
        temperature=0.2,
    )

    result = json.loads(response.choices[0].message.content)
    return result.get("species", [])


# ---------------------------------------------------------------------------
# Step 5: Format Output
# ---------------------------------------------------------------------------

def format_plant_json(species: dict, traits: dict) -> dict:
    """Format a species + traits into a Plants.json-compatible entry."""
    return {
        "Plant_Name_Latin": species["scientific_name"],
        "Plant_Name_Common": species["common_name"],
        "Plant_Kingdom": species.get("kingdom", "Plantae"),
        "Plant_Class": species.get("class", ""),
        "Plant_Order": species.get("order", ""),
        "Plant_Family": species.get("family", ""),
        "Plant_Genus": species.get("genus", ""),
        "Plant_Description": "",
        "Leaf_Type": traits.get("Leaf_Type"),
        "Leaf_Attachment": traits.get("Leaf_Attachment"),
        "Leaf_Arrangement": traits.get("Leaf_Arrangement"),
        "Leaf_Shape": traits.get("Leaf_Shape"),
        "Leaf_Margin": traits.get("Leaf_Margin"),
        "Leaf_Apex": traits.get("Leaf_Apex"),
        "Leaf_Base": traits.get("Leaf_Base"),
        "Leaf_Venation": traits.get("Leaf_Venation"),
        "Leaf_Texture": traits.get("Leaf_Texture"),
        "Leaf_Stipules": traits.get("Leaf_Stipules"),
        "Stem_Habit": traits.get("Stem_Habit"),
        "Stem_Structure": traits.get("Stem_Structure"),
        "Stem_Branching": traits.get("Stem_Branching"),
        "Flower_Inflorescence": traits.get("Flower_Inflorescence"),
        "Flower_Symmetry": traits.get("Flower_Symmetry"),
        "Flower_Petal Count": traits.get("Flower_Petal Count"),
        "Flower_Petal Fusion": traits.get("Flower_Petal Fusion"),
        "Flower_Sepal Presence": traits.get("Flower_Sepal Presence"),
        "Flower_Sepal Fusion": traits.get("Flower_Sepal Fusion"),
        "Flower_Color": traits.get("Flower_Color"),
        "Flower_Position": traits.get("Flower_Position"),
        "Flower_Ovary Position": traits.get("Flower_Ovary Position"),
        "Flower_Sexuality": traits.get("Flower_Sexuality"),
        "Flower_Floral Part": traits.get("Flower_Floral Part"),
        "Fruit_Type": traits.get("Fruit_Type"),
        "Fruit_Seed Trait": traits.get("Fruit_Seed Trait"),
        "Root_Type": traits.get("Root_Type"),
        "Environment_Habitat": traits.get("Environment_Habitat"),
        "Environment_Soil": traits.get("Environment_Soil"),
        "Environment_Growth Habit": traits.get("Environment_Growth Habit"),
        "Bloom_Months": traits.get("Bloom_Months"),
        "Fruit_Months": traits.get("Fruit_Months"),
    }


# ---------------------------------------------------------------------------
# Main Pipeline
# ---------------------------------------------------------------------------

def run_region(region_key: str, region: dict, args, existing: Set[str], already_processed: Set[str]) -> List[dict]:
    """Process a single region and return new plant entries."""
    print(f"\n{'='*60}")
    print(f"  REGION: {region['name']} ({region_key})")
    print(f"{'='*60}")

    # ── Step 1: Discover species via GBIF ──
    print("\n  --- Species Discovery (GBIF) ---")
    species_keys = fetch_gbif_species(region, max_species=args.max_species)

    # ── Step 2: Enrich taxonomy ──
    print(f"\n  --- GBIF Taxonomy Enrichment ({len(species_keys)} species) ---")
    enriched = []
    for i, sk in enumerate(species_keys):
        sp = enrich_species(sk["gbif_key"])
        if sp:
            sp["occurrence_count"] = sk["occurrence_count"]
            enriched.append(sp)

        if (i + 1) % 100 == 0:
            print(f"    Enriched {i + 1}/{len(species_keys)}...")
            time.sleep(1)  # Be nice to GBIF
        elif (i + 1) % 20 == 0:
            time.sleep(0.3)

    print(f"    Enriched {len(enriched)} valid species")

    # ── Step 3: Deduplicate against existing + previously processed regions ──
    skip = existing | already_processed
    new_species = [sp for sp in enriched if sp["scientific_name"] not in skip]
    dupes = len(enriched) - len(new_species)
    print(f"    Removed {dupes} duplicates, {len(new_species)} new species remaining")

    # Sort by occurrence count (most common first)
    new_species.sort(key=lambda x: x.get("occurrence_count", 0), reverse=True)

    # Apply per-region limit
    if args.limit > 0:
        new_species = new_species[:args.limit]
        print(f"    Limited to top {args.limit} species")

    if args.dry_run:
        print(f"\n  DRY RUN: {len(new_species)} new species from {region['name']}")
        for i, sp in enumerate(new_species[:15]):
            print(f"    {i+1:3d}. {sp['scientific_name']:40s} "
                  f"({sp['common_name'][:25]:25s}) "
                  f"— {sp['family']}, {sp.get('occurrence_count', '?'):>8,} obs")
        if len(new_species) > 15:
            print(f"    ... and {len(new_species) - 15} more")
        return new_species  # Return enriched but without traits for dry-run

    if not new_species:
        print(f"    No new species to process for {region['name']}")
        return []

    # ── Step 4: Generate traits with OpenAI ──
    print(f"\n  --- AI Trait Generation ({len(new_species)} species) ---")
    from openai import OpenAI
    openai_key = os.environ.get("OPENAI_API_KEY")
    if not openai_key:
        print("  Error: OPENAI_API_KEY not set")
        sys.exit(1)

    client = OpenAI(api_key=openai_key)
    vocabulary = load_vocabulary()

    region_plants = []
    batch_size = args.batch_size

    for batch_start in range(0, len(new_species), batch_size):
        batch = new_species[batch_start:batch_start + batch_size]
        batch_end = min(batch_start + batch_size, len(new_species))
        print(f"    Batch {batch_start + 1}-{batch_end} of {len(new_species)}...")

        try:
            trait_results = generate_traits_batch(batch, vocabulary, client)
        except Exception as e:
            print(f"      Error generating traits: {e}")
            for sp in batch:
                region_plants.append(format_plant_json(sp, {}))
            continue

        # Match traits back to species
        trait_map = {t.get("scientific_name", ""): t for t in trait_results}
        for sp in batch:
            traits = trait_map.get(sp["scientific_name"], {})
            region_plants.append(format_plant_json(sp, traits))

        # Rate limiting
        if batch_end < len(new_species):
            time.sleep(1.5)

    return region_plants


def main():
    all_region_keys = list(REGIONS.keys())

    parser = argparse.ArgumentParser(description="Expand RadicleBotany Plants.json")
    parser.add_argument("--region", choices=all_region_keys,
                        help="Single region to query")
    parser.add_argument("--all-regions", action="store_true",
                        help="Run all 8 North American regions")
    parser.add_argument("--dry-run", action="store_true",
                        help="Only fetch species list, skip trait generation")
    parser.add_argument("--limit", type=int, default=0,
                        help="Limit new species per region (0 = all)")
    parser.add_argument("--max-species", type=int, default=500,
                        help="Max species to request from GBIF per region (default 500)")
    parser.add_argument("--batch-size", type=int, default=10,
                        help="Species per OpenAI API call")
    parser.add_argument("--output", type=str, default=None,
                        help="Output filename")
    args = parser.parse_args()

    if not args.region and not args.all_regions:
        parser.error("Either --region or --all-regions is required")

    regions_to_run = all_region_keys if args.all_regions else [args.region]

    # Load existing species once
    print("\n=== Loading existing database ===")
    existing = load_existing_species()

    all_plants = []
    already_processed = set()  # Cross-region deduplication

    for region_key in regions_to_run:
        region = REGIONS[region_key]
        region_plants = run_region(region_key, region, args, existing, already_processed)

        # Track what we've processed for cross-region dedup
        for sp in region_plants:
            name = sp.get("scientific_name") or sp.get("Plant_Name_Latin", "")
            already_processed.add(name)

        all_plants.extend(region_plants)

    # Determine output path
    if args.output:
        output_file = args.output
    elif args.all_regions:
        output_file = "new_plants_north_america.json"
    else:
        output_file = f"new_plants_{args.region}.json"
    output_path = SCRIPT_DIR / output_file

    if args.dry_run:
        print(f"\n{'='*60}")
        print(f"  DRY RUN SUMMARY: {len(all_plants)} total new species across {len(regions_to_run)} region(s)")
        print(f"{'='*60}")
        sys.exit(0)

    # ── Output ──
    print(f"\n{'='*60}")
    print(f"  FINAL OUTPUT")
    print(f"{'='*60}")

    # Sort all plants alphabetically by scientific name
    all_plants.sort(key=lambda x: x.get("Plant_Name_Latin", ""))

    with open(output_path, "w") as f:
        json.dump(all_plants, f, indent=2, ensure_ascii=False)
    print(f"  Saved {len(all_plants)} new species to {output_path}")

    # Validate JSON
    with open(output_path, "r") as f:
        validated = json.loads(f.read())
    print(f"  JSON validation passed ({len(validated)} entries)")

    # Summary
    print(f"\n=== Summary ===")
    print(f"  Regions processed: {', '.join(regions_to_run)}")
    print(f"  Existing species: {len(existing)}")
    print(f"  New species generated: {len(all_plants)}")
    print(f"  Output: {output_path}")
    print(f"\n  To merge into Plants.json, run:")
    print(f"    python3 scripts/merge_plants.py")


if __name__ == "__main__":
    main()
