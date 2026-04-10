import json
import random
from pathlib import Path

from locust import HttpUser, between, task


def _load_slug_names():
    """Load slug names once at startup for detail and duel traffic."""
    candidates = [
        Path(__file__).resolve().parent / "config" / "slugs_data.json",
        Path(__file__).resolve().parent / "slugs_data.json",
    ]

    for file_path in candidates:
        if not file_path.exists():
            continue

        with file_path.open("r", encoding="utf-8") as f:
            data = json.load(f)

        names = [item.get("slug-name") for item in data if item.get("slug-name")]
        if names:
            return names

    # Fallback for environments where data files are missing.
    return ["Aquabeek", "Infurnus", "Tazerling", "Flaringo"]


SLUG_NAMES = _load_slug_names()
ELEMENT_FILTERS = ["fire", "water", "earth", "air", "ice", "plant", "toxic", "psychic", "electricity"]
RARITY_FILTERS = ["common", "uncommon", "rare", "extremely rare", "ultra rare", "one-of-a-kind"]


class SlugTerraUser(HttpUser):
    wait_time = between(0.5, 2.0)

    @task(2)
    def home(self):
        with self.client.get("/", name="GET /", catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")

    @task(8)
    def list_slugs(self):
        params = {
            "page": random.randint(1, 4),
            "page_size": random.choice([12, 24, 48]),
        }
        with self.client.get("/api/slugs/", params=params, name="GET /api/slugs/", catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")

    @task(4)
    def list_slugs_filtered(self):
        params = {
            "element": random.choice(ELEMENT_FILTERS),
            "rarity": random.choice(RARITY_FILTERS),
            "page_size": 24,
        }
        with self.client.get(
            "/api/slugs/",
            params=params,
            name="GET /api/slugs/?filters",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")

    @task(2)
    def stats(self):
        with self.client.get("/api/slugs/stats/", name="GET /api/slugs/stats/", catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")

    @task(6)
    def slug_detail(self):
        slug_name = random.choice(SLUG_NAMES)
        with self.client.get(
            f"/api/slugs/{slug_name}/",
            name="GET /api/slugs/:name/",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")

    @task(3)
    def slug_duel(self):
        slug_a, slug_b = random.sample(SLUG_NAMES, 2)
        params = {
            "slug_a": slug_a,
            "slug_b": slug_b,
            "rounds": random.randint(1, 9),
            "seed": random.randint(1, 10000),
        }
        with self.client.get(
            "/api/slugs/duel/",
            params=params,
            name="GET /api/slugs/duel/",
            catch_response=True,
        ) as response:
            if response.status_code != 200:
                response.failure(f"Expected 200, got {response.status_code}")