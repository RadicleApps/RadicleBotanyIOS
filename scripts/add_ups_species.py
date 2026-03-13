#!/usr/bin/env python3
"""
Add missing UPS (United Plant Savers) species to Plants.json.

These 16 species are listed in the app's conservation view but are missing
from the plant database, meaning they have no images or detail pages.

12 species with completely missing genera:
  Chamaelirium luteum, Lophophora williamsii, Santalum album,
  Aletris farinosa, Dionaea muscipula, Castela emoryi,
  Hydrastis canadensis, Piper methysticum, Ligusticum porteri,
  Aristolochia serpentaria, Acorus calamus, Euphrasia officinalis

4 species where genus exists but exact species is missing:
  Panax quinquefolius, Actaea racemosa, Ulmus rubra, Baptisia tinctoria
"""

import json
import urllib.request
import urllib.parse
import time
import sys
import os

# iNaturalist API for image fetching
INAT_TAXA_URL = "https://api.inaturalist.org/v1/taxa"
USER_AGENT = "RadicleBotany/1.0 (iOS; educational botany app; species-enrichment)"


def fetch_inat_images(scientific_name: str) -> dict:
    """Fetch image URLs from iNaturalist for a species."""
    params = urllib.parse.urlencode({
        "q": scientific_name,
        "rank": "species",
        "per_page": "1",
        "locale": "en"
    })
    url = f"{INAT_TAXA_URL}?{params}"

    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            data = json.loads(resp.read())
    except Exception as e:
        print(f"  ⚠️ iNat search failed for {scientific_name}: {e}")
        return {}

    results = data.get("results", [])
    if not results:
        # Try genus-level search
        genus = scientific_name.split()[0]
        print(f"  ⚠️ No exact match, trying genus: {genus}")
        params = urllib.parse.urlencode({
            "q": genus,
            "per_page": "1",
            "locale": "en"
        })
        url = f"{INAT_TAXA_URL}?{params}"
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read())
        except Exception as e:
            print(f"  ⚠️ iNat genus search failed: {e}")
            return {}
        results = data.get("results", [])
        if not results:
            return {}

    taxon = results[0]
    taxon_name = taxon.get("name", "")

    # For species-level search, verify match
    if not taxon_name.lower().startswith(scientific_name.split()[0].lower()):
        print(f"  ⚠️ Name mismatch: got '{taxon_name}' for '{scientific_name}'")
        return {}

    # Get default photo
    images = {}
    default_photo = taxon.get("default_photo", {})
    if default_photo:
        photo_url = default_photo.get("medium_url") or default_photo.get("square_url", "")
        if photo_url:
            photo_url = photo_url.replace("/square.", "/medium.")
            images["image_url"] = photo_url

    # Fetch detailed taxon info for additional photos
    taxon_id = taxon.get("id")
    if taxon_id:
        detail_url = f"{INAT_TAXA_URL}/{taxon_id}"
        req = urllib.request.Request(detail_url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                detail_data = json.loads(resp.read())
            detail_results = detail_data.get("results", [])
            if detail_results:
                taxon_photos = detail_results[0].get("taxon_photos", [])
                organ_keys = [
                    "flower_image_url", "leaf_image_url", "fruit_image_url",
                    "bark_image_url", "stem_image_url", "habit_image_url"
                ]
                for i, key in enumerate(organ_keys):
                    photo_idx = i + 1  # Skip first (already used as general)
                    if photo_idx < len(taxon_photos):
                        photo = taxon_photos[photo_idx].get("photo", {})
                        if photo:
                            url = photo.get("medium_url") or photo.get("square_url", "")
                            if url:
                                images[key] = url.replace("/square.", "/medium.")
        except Exception as e:
            print(f"  ⚠️ iNat detail fetch failed: {e}")

    return images


# Define the 16 species with accurate botanical data
NEW_SPECIES = [
    # ========== CRITICAL (missing genera) ==========
    {
        "Plant_Name_Latin": "Chamaelirium luteum",
        "Plant_Name_Common": "False Unicorn",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Liliopsida",
        "Plant_Order": "Liliales",
        "Plant_Family": "Melanthiaceae",
        "Plant_Genus": "Chamaelirium",
        "Plant_Description": "A dioecious perennial herb prized in traditional herbalism. Its slow growth and specific habitat requirements make wild populations extremely vulnerable.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Sessile",
        "Leaf_Arrangement": "Basal rosette",
        "Leaf_Shape": "Linear",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Attenuate",
        "Leaf_Venation": "Parallel",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Raceme",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "6 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Tepals",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Unisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Capsule",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Moist meadows and woodlands",
        "Environment_Soil": "Rich, moist, acidic",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "5,6,7",
        "Fruit_Months": "8,9",
    },
    {
        "Plant_Name_Latin": "Lophophora williamsii",
        "Plant_Name_Common": "Peyote",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Caryophyllales",
        "Plant_Family": "Cactaceae",
        "Plant_Genus": "Lophophora",
        "Plant_Description": "A small, spineless cactus with profound cultural significance to indigenous peoples. It grows extremely slowly and faces severe pressure from illegal harvesting.",
        "Leaf_Type": None,
        "Leaf_Attachment": None,
        "Leaf_Arrangement": None,
        "Leaf_Shape": None,
        "Leaf_Margin": None,
        "Leaf_Apex": None,
        "Leaf_Base": None,
        "Leaf_Venation": None,
        "Leaf_Texture": None,
        "Leaf_Stipules": None,
        "Stem_Habit": "Prostrate",
        "Stem_Structure": "Succulent",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Solitary",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "Multiple petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Tepals",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "Pink Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Epigynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Berry",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Desert scrubland",
        "Environment_Soil": "Well-drained, alkaline, rocky",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "3,4,5,6",
        "Fruit_Months": "6,7,8",
    },
    {
        "Plant_Name_Latin": "Santalum album",
        "Plant_Name_Common": "Sandalwood",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Santalales",
        "Plant_Family": "Santalaceae",
        "Plant_Genus": "Santalum",
        "Plant_Description": "An evergreen hemiparasitic tree prized for its fragrant heartwood and essential oil. Multiple species worldwide face critical decline due to centuries of overexploitation.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Opposite",
        "Leaf_Shape": "Elliptic",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Woody",
        "Stem_Branching": "Opposite",
        "Flower_Inflorescence": "Panicle",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "4 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Tepals",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "Purple Petals",
        "Flower_Position": "Axillary",
        "Flower_Ovary Position": "Epigynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Drupe",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Tropical dry forest",
        "Environment_Soil": "Well-drained, sandy loam",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "3,4,5,6,7",
        "Fruit_Months": "7,8,9,10",
    },
    {
        "Plant_Name_Latin": "Aletris farinosa",
        "Plant_Name_Common": "True Unicorn",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Liliopsida",
        "Plant_Order": "Dioscoreales",
        "Plant_Family": "Nartheciaceae",
        "Plant_Genus": "Aletris",
        "Plant_Description": "A grasslike perennial with a distinctive white, mealy flower spike. It has been overharvested for traditional medicine and is now increasingly rare across its range.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Sessile",
        "Leaf_Arrangement": "Basal rosette",
        "Leaf_Shape": "Linear",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Attenuate",
        "Leaf_Venation": "Parallel",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Raceme",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "6 Petals",
        "Flower_Petal Fusion": "Sympetalous",
        "Flower_Sepal Presence": "Tepals",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Capsule",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Moist meadows and savannas",
        "Environment_Soil": "Moist, sandy, acidic",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "5,6,7",
        "Fruit_Months": "8,9",
    },
    {
        "Plant_Name_Latin": "Dionaea muscipula",
        "Plant_Name_Common": "Venus Fly Trap",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Caryophyllales",
        "Plant_Family": "Droseraceae",
        "Plant_Genus": "Dionaea",
        "Plant_Description": "One of nature's most recognizable carnivorous plants, capable of snapping shut on insect prey in milliseconds. It exists naturally in only a tiny range of coastal Carolina wetlands.",
        "Leaf_Type": "Modified",
        "Leaf_Attachment": "Sessile",
        "Leaf_Arrangement": "Basal rosette",
        "Leaf_Shape": "Orbicular",
        "Leaf_Margin": "Ciliate",
        "Leaf_Apex": "Round",
        "Leaf_Base": "Truncate",
        "Leaf_Venation": "Palmate",
        "Leaf_Texture": "Glandular",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Rosette",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Cyme",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "5 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Aposepalous",
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Capsule",
        "Fruit_Seed Trait": None,
        "Root_Type": "Fibrous",
        "Environment_Habitat": "Longleaf pine savanna bogs",
        "Environment_Soil": "Wet, nutrient-poor, acidic",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "5,6",
        "Fruit_Months": "7,8",
    },
    # ========== AT-RISK (missing genera) ==========
    {
        "Plant_Name_Latin": "Castela emoryi",
        "Plant_Name_Common": "Chaparro Amargoso",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Sapindales",
        "Plant_Family": "Simaroubaceae",
        "Plant_Genus": "Castela",
        "Plant_Description": "A thorny desert shrub native to the Sonoran Desert, used traditionally for digestive ailments. Its extremely bitter compounds give it the name 'chaparro amargoso' (bitter bush).",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Sessile",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Oblong",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Obtuse",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Pubescent",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Woody",
        "Stem_Branching": "Alternate",
        "Flower_Inflorescence": "Solitary",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "4 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Aposepalous",
        "Flower_Color": "Red Petals",
        "Flower_Position": "Axillary",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Unisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Drupe",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Desert scrubland",
        "Environment_Soil": "Well-drained, sandy, alkaline",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "4,5,6,7",
        "Fruit_Months": "7,8,9",
    },
    {
        "Plant_Name_Latin": "Hydrastis canadensis",
        "Plant_Name_Common": "Goldenseal",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Ranunculales",
        "Plant_Family": "Ranunculaceae",
        "Plant_Genus": "Hydrastis",
        "Plant_Description": "One of the most heavily traded wild medicinal plants in North America. Its bright yellow rhizome contains berberine, driving intense commercial harvesting that has devastated populations.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Palmate",
        "Leaf_Margin": "Serrate",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Cordate",
        "Leaf_Venation": "Palmate",
        "Leaf_Texture": "Pubescent",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Solitary",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "Absent petals",
        "Flower_Petal Fusion": "Apetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Aposepalous",
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Berry",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Rich deciduous woodland",
        "Environment_Soil": "Rich, moist, humus-rich",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "4,5",
        "Fruit_Months": "7,8",
    },
    {
        "Plant_Name_Latin": "Piper methysticum",
        "Plant_Name_Common": "Kava",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Piperales",
        "Plant_Family": "Piperaceae",
        "Plant_Genus": "Piper",
        "Plant_Description": "A culturally significant plant in Pacific Island societies, used for centuries in ceremonial and social beverages. Growing global demand for its calming properties threatens wild sources.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Cordate",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acuminate",
        "Leaf_Base": "Cordate",
        "Leaf_Venation": "Palmate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Stipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": "Alternate",
        "Flower_Inflorescence": "Spike",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "Absent petals",
        "Flower_Petal Fusion": "Apetalous",
        "Flower_Sepal Presence": "Sepals absent",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "Green Petals",
        "Flower_Position": "Axillary",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Unisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Drupe",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Tropical forest understory",
        "Environment_Soil": "Rich, moist, volcanic",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": None,
        "Fruit_Months": None,
    },
    {
        "Plant_Name_Latin": "Ligusticum porteri",
        "Plant_Name_Common": "Osha",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Apiales",
        "Plant_Family": "Apiaceae",
        "Plant_Genus": "Ligusticum",
        "Plant_Description": "A high-altitude medicinal herb with a large aromatic root, widely used in traditional medicine of the American Southwest. Cannot be cultivated, making wild populations the only source.",
        "Leaf_Type": "Compound",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Pinnate",
        "Leaf_Margin": "Serrate",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": "Alternate",
        "Flower_Inflorescence": "Compound umbel",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "5 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Aposepalous",
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Epigynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Schizocarp",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Mountain meadows and coniferous forests",
        "Environment_Soil": "Rich, moist, well-drained",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "6,7,8",
        "Fruit_Months": "8,9,10",
    },
    {
        "Plant_Name_Latin": "Aristolochia serpentaria",
        "Plant_Name_Common": "Virginia Snakeroot",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Piperales",
        "Plant_Family": "Aristolochiaceae",
        "Plant_Genus": "Aristolochia",
        "Plant_Description": "A small woodland perennial with distinctive pipe-shaped flowers. Historically important in colonial-era medicine, its aromatic root was used as a snakebite remedy.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Cordate",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acuminate",
        "Leaf_Base": "Cordate",
        "Leaf_Venation": "Palmate",
        "Leaf_Texture": "Pubescent",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Solitary",
        "Flower_Symmetry": "Zygomorphic",
        "Flower_Petal Count": "Absent petals",
        "Flower_Petal Fusion": "Apetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Synsepalous",
        "Flower_Color": "Brown Petals",
        "Flower_Position": "Basal",
        "Flower_Ovary Position": "Epigynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Capsule",
        "Fruit_Seed Trait": None,
        "Root_Type": "Fibrous",
        "Environment_Habitat": "Rich deciduous woodland",
        "Environment_Soil": "Rich, moist, humus-rich",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "5,6,7",
        "Fruit_Months": "8,9",
    },
    # ========== TO WATCH (missing genera) ==========
    {
        "Plant_Name_Latin": "Acorus calamus",
        "Plant_Name_Common": "Sweet Flag",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Liliopsida",
        "Plant_Order": "Acorales",
        "Plant_Family": "Acoraceae",
        "Plant_Genus": "Acorus",
        "Plant_Description": "A wetland perennial with aromatic sword-shaped leaves and rhizomes. Used for thousands of years in traditional medicine across multiple cultures worldwide.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Sheathing",
        "Leaf_Arrangement": "Basal",
        "Leaf_Shape": "Linear",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Sheathing",
        "Leaf_Venation": "Parallel",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Spadix",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "6 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Tepals",
        "Flower_Sepal Fusion": None,
        "Flower_Color": "Green Petals",
        "Flower_Position": "Lateral",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Berry",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Wetlands and stream edges",
        "Environment_Soil": "Wet, marshy, organic-rich",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "5,6,7",
        "Fruit_Months": "7,8,9",
    },
    {
        "Plant_Name_Latin": "Euphrasia officinalis",
        "Plant_Name_Common": "Eyebright",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Lamiales",
        "Plant_Family": "Orobanchaceae",
        "Plant_Genus": "Euphrasia",
        "Plant_Description": "A small hemiparasitic annual herb used traditionally for eye ailments. Difficult to cultivate due to its parasitic nature, making it dependent on wild harvest.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Sessile",
        "Leaf_Arrangement": "Opposite",
        "Leaf_Shape": "Ovate",
        "Leaf_Margin": "Dentate",
        "Leaf_Apex": "Acute",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Pubescent",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": "Opposite",
        "Flower_Inflorescence": "Spike",
        "Flower_Symmetry": "Zygomorphic",
        "Flower_Petal Count": "5 Petals",
        "Flower_Petal Fusion": "Sympetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Synsepalous",
        "Flower_Color": "White Petals",
        "Flower_Position": "Axillary",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Capsule",
        "Fruit_Seed Trait": None,
        "Root_Type": "Fibrous",
        "Environment_Habitat": "Grasslands and meadows",
        "Environment_Soil": "Well-drained, alkaline to neutral",
        "Environment_Growth Habit": "Annual",
        "Bloom_Months": "6,7,8,9",
        "Fruit_Months": "8,9,10",
    },
    # ========== EXACT-NAME SPECIES (genus exists, species doesn't) ==========
    {
        "Plant_Name_Latin": "Panax quinquefolius",
        "Plant_Name_Common": "American Ginseng",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Apiales",
        "Plant_Family": "Araliaceae",
        "Plant_Genus": "Panax",
        "Plant_Description": "One of the most economically valuable wild-harvested plants in North America. Its slow growth, high market value, and specific habitat needs make it particularly vulnerable to overharvesting.",
        "Leaf_Type": "Compound",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Whorled",
        "Leaf_Shape": "Palmate",
        "Leaf_Margin": "Serrate",
        "Leaf_Apex": "Acuminate",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Umbel",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "5 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Synsepalous",
        "Flower_Color": "Green Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Epigynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Berry",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Rich shaded hardwood forests",
        "Environment_Soil": "Rich, moist, well-drained",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "6,7",
        "Fruit_Months": "8,9",
    },
    {
        "Plant_Name_Latin": "Actaea racemosa",
        "Plant_Name_Common": "Black Cohosh",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Ranunculales",
        "Plant_Family": "Ranunculaceae",
        "Plant_Genus": "Actaea",
        "Plant_Description": "A tall, elegant woodland perennial widely used in herbal medicine for menopausal symptoms. Increasing global demand has put severe pressure on wild populations throughout Appalachia.",
        "Leaf_Type": "Compound",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Ovate",
        "Leaf_Margin": "Serrate",
        "Leaf_Apex": "Acuminate",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Exstipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": None,
        "Flower_Inflorescence": "Raceme",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "Absent petals",
        "Flower_Petal Fusion": "Apetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Aposepalous",
        "Flower_Color": "White Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Follicle",
        "Fruit_Seed Trait": None,
        "Root_Type": "Rhizome",
        "Environment_Habitat": "Rich moist deciduous forests",
        "Environment_Soil": "Rich, moist, humus-rich",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "6,7,8",
        "Fruit_Months": "9,10",
    },
    {
        "Plant_Name_Latin": "Ulmus rubra",
        "Plant_Name_Common": "Slippery Elm",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Rosales",
        "Plant_Family": "Ulmaceae",
        "Plant_Genus": "Ulmus",
        "Plant_Description": "A medium-sized deciduous tree valued for its mucilaginous inner bark, used medicinally for sore throats and digestive issues. Trees are often killed by bark stripping, compounding losses from Dutch elm disease.",
        "Leaf_Type": "Simple",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Obovate",
        "Leaf_Margin": "Doubly Serrate",
        "Leaf_Apex": "Acuminate",
        "Leaf_Base": "Oblique",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Scabrous",
        "Leaf_Stipules": "Stipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Woody",
        "Stem_Branching": "Alternate",
        "Flower_Inflorescence": "Cluster",
        "Flower_Symmetry": "Actinomorphic",
        "Flower_Petal Count": "Absent petals",
        "Flower_Petal Fusion": "Apetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Synsepalous",
        "Flower_Color": "Green Petals",
        "Flower_Position": "Axillary",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Samara",
        "Fruit_Seed Trait": "Seed wing",
        "Root_Type": "Taproot",
        "Environment_Habitat": "Moist lowlands and floodplains",
        "Environment_Soil": "Rich, moist, well-drained",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "3,4",
        "Fruit_Months": "5,6",
    },
    {
        "Plant_Name_Latin": "Baptisia tinctoria",
        "Plant_Name_Common": "Wild Indigo",
        "Plant_Kingdom": "Plantae",
        "Plant_Class": "Magnoliopsida",
        "Plant_Order": "Fabales",
        "Plant_Family": "Fabaceae",
        "Plant_Genus": "Baptisia",
        "Plant_Description": "A native legume once used to produce blue dye. Its deep taproot fixes nitrogen in soil, making it ecologically valuable in prairie and woodland edge habitats.",
        "Leaf_Type": "Compound",
        "Leaf_Attachment": "Petiolate",
        "Leaf_Arrangement": "Alternate",
        "Leaf_Shape": "Obovate",
        "Leaf_Margin": "Entire",
        "Leaf_Apex": "Obtuse",
        "Leaf_Base": "Cuneate",
        "Leaf_Venation": "Pinnate",
        "Leaf_Texture": "Glabrous",
        "Leaf_Stipules": "Stipulate",
        "Stem_Habit": "Erect",
        "Stem_Structure": "Herbaceous",
        "Stem_Branching": "Alternate",
        "Flower_Inflorescence": "Raceme",
        "Flower_Symmetry": "Zygomorphic",
        "Flower_Petal Count": "5 Petals",
        "Flower_Petal Fusion": "Apopetalous",
        "Flower_Sepal Presence": "Sepals present",
        "Flower_Sepal Fusion": "Synsepalous",
        "Flower_Color": "Yellow Petals",
        "Flower_Position": "Terminal",
        "Flower_Ovary Position": "Hypogynous",
        "Flower_Sexuality": "Bisexual",
        "Flower_Floral Part": None,
        "Fruit_Type": "Legume",
        "Fruit_Seed Trait": None,
        "Root_Type": "Taproot",
        "Environment_Habitat": "Dry woodlands and prairies",
        "Environment_Soil": "Well-drained, sandy",
        "Environment_Growth Habit": "Perennial",
        "Bloom_Months": "6,7,8",
        "Fruit_Months": "9,10",
    },
]


def main():
    # Path to Plants.json (bundle copy - this is what gets loaded)
    bundle_path = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                                "RadicleBotany", "Plants.json")
    # Also the root copy
    root_path = os.path.join(os.path.dirname(os.path.dirname(__file__)),
                              "RadicleBotany_Plants.json")

    # Read existing data
    print(f"📖 Reading {bundle_path}...")
    with open(bundle_path, "r", encoding="utf-8") as f:
        plants = json.load(f)

    existing_names = {p["Plant_Name_Latin"].lower() for p in plants}
    print(f"   Found {len(plants)} existing species")

    # Check which species need to be added
    to_add = []
    for species in NEW_SPECIES:
        name = species["Plant_Name_Latin"].lower()
        if name in existing_names:
            print(f"   ⏭️  {species['Plant_Name_Latin']} already exists, skipping")
        else:
            to_add.append(species)

    if not to_add:
        print("✅ All species already in database!")
        return

    print(f"\n🌿 Adding {len(to_add)} new species...")

    # Fetch iNaturalist images for each
    for i, species in enumerate(to_add):
        name = species["Plant_Name_Latin"]
        print(f"\n[{i+1}/{len(to_add)}] Fetching images for {name}...")
        images = fetch_inat_images(name)

        # Apply image URLs
        species["image_url"] = images.get("image_url")
        species["flower_image_url"] = images.get("flower_image_url")
        species["leaf_image_url"] = images.get("leaf_image_url")
        species["fruit_image_url"] = images.get("fruit_image_url")
        species["bark_image_url"] = images.get("bark_image_url")
        species["stem_image_url"] = images.get("stem_image_url")
        species["habit_image_url"] = images.get("habit_image_url")
        species["gbif_id"] = None

        img_count = sum(1 for k in ["image_url", "flower_image_url", "leaf_image_url",
                                     "fruit_image_url", "bark_image_url", "stem_image_url",
                                     "habit_image_url"] if species.get(k))
        print(f"   ✅ {name}: {img_count} images found")

        # Be polite to iNaturalist API
        if i < len(to_add) - 1:
            time.sleep(1.0)

    # Add new species to the list
    plants.extend(to_add)

    # Sort alphabetically by scientific name
    plants.sort(key=lambda p: p["Plant_Name_Latin"])

    # Write updated JSON to bundle path
    print(f"\n💾 Writing {len(plants)} species to {bundle_path}...")
    with open(bundle_path, "w", encoding="utf-8") as f:
        json.dump(plants, f, indent=2, ensure_ascii=False)

    # Also write to root path
    if os.path.exists(root_path):
        print(f"💾 Writing {len(plants)} species to {root_path}...")
        with open(root_path, "w", encoding="utf-8") as f:
            json.dump(plants, f, indent=2, ensure_ascii=False)

    print(f"\n🎉 Done! Added {len(to_add)} species. Total: {len(plants)} species.")
    print("\nAdded species:")
    for s in to_add:
        print(f"   • {s['Plant_Name_Latin']} ({s['Plant_Name_Common']})")


if __name__ == "__main__":
    main()
