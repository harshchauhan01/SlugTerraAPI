import json
import random
from collections import Counter
from functools import lru_cache
from pathlib import Path

from django.core.cache import cache
from rest_framework.decorators import api_view
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response


DATA_FILE = Path(__file__).resolve().parents[1] / "slugs_data.json"
CACHE_KEY_PREFIX = "slugs:data"
CACHE_TTL_SECONDS = 300
PAGE_SIZE = 24
MAX_PAGE_SIZE = 100
RARITY_SCORE = {
    "one-of-a-kind": 7,
    "ultra rare": 6,
    "extremely rare": 5,
    "rare": 4,
    "uncommon": 3,
    "common": 2,
}

ELEMENT_ADVANTAGES = {
    "fire": {"plant", "ice", "toxic"},
    "water": {"fire", "earth"},
    "earth": {"electricity", "toxic"},
    "electricity": {"water", "air"},
    "air": {"earth", "plant"},
    "ice": {"air", "plant"},
    "plant": {"water", "earth"},
    "psychic": {"air", "electricity"},
    "toxic": {"plant", "water"},
}


def _normalize(value):
    return value.strip().lower()


def _get_data_version():
    stat = DATA_FILE.stat()
    return f"{stat.st_mtime_ns}:{stat.st_size}"


@lru_cache(maxsize=2)
def _build_dataset(data_version):
    with DATA_FILE.open("r", encoding="utf-8") as data_file:
        slugs = json.load(data_file)

    slug_map = {}
    search_index = []

    for slug in slugs:
        slug_name = slug.get("slug-name", "")
        info = slug.get("info", {})

        slug_name_norm = _normalize(slug_name)
        slug_element_norm = _normalize(info.get("element", ""))
        slug_rarity_norm = _normalize(info.get("rarity", ""))
        slug_power_type_norm = _normalize(info.get("power_type", ""))

        slug_map[slug_name_norm] = slug
        search_index.append(
            {
                "slug": slug,
                "slug_name": slug_name_norm,
                "element": slug_element_norm,
                "rarity": slug_rarity_norm,
                "power_type": slug_power_type_norm,
            }
        )

    return {
        "slugs": slugs,
        "slug_map": slug_map,
        "search_index": search_index,
        "stats": _build_stats(slugs),
    }


def _load_slugs_data():
    """Read slug dataset with cache-backed precomputed indexes."""
    cache_version = _get_data_version()
    cache_key = f"{CACHE_KEY_PREFIX}:{cache_version}"

    dataset = cache.get(cache_key)
    if dataset is not None:
        return dataset

    dataset = _build_dataset(cache_version)
    cache.set(cache_key, dataset, timeout=CACHE_TTL_SECONDS)
    return dataset


def _find_slug(slug_map, slug_name):
    return slug_map.get(_normalize(slug_name))


def _safe_int(value, default):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _rarity_score(slug):
    rarity = _normalize(slug.get("info", {}).get("rarity", ""))
    return RARITY_SCORE.get(rarity, 1)


def _element_bonus(first_slug, second_slug):
    first_element = _normalize(first_slug.get("info", {}).get("element", ""))
    second_element = _normalize(second_slug.get("info", {}).get("element", ""))

    if second_element in ELEMENT_ADVANTAGES.get(first_element, set()):
        return 2
    return 0


def _slug_power_score(slug, opponent_slug, rng):
    attacks_count = len(slug.get("attacks", {}).get("list", []))
    rarity_bonus = _rarity_score(slug)
    element_bonus = _element_bonus(slug, opponent_slug)

    power_type = _normalize(slug.get("info", {}).get("power_type", ""))
    ghoul_bonus = 1 if "ghoul" in power_type else 0
    momentum_roll = rng.randint(0, 3)

    return {
        "score": min(attacks_count, 10) + rarity_bonus + element_bonus + ghoul_bonus + momentum_roll,
        "breakdown": {
            "attacks": min(attacks_count, 10),
            "rarity_bonus": rarity_bonus,
            "element_bonus": element_bonus,
            "ghoul_bonus": ghoul_bonus,
            "momentum_roll": momentum_roll,
        },
    }


def _simulate_duel(slug_a, slug_b, rounds, seed):
    rng = random.Random(seed)
    rounds_data = []
    slug_a_points = 0
    slug_b_points = 0

    for round_number in range(1, rounds + 1):
        slug_a_result = _slug_power_score(slug_a, slug_b, rng)
        slug_b_result = _slug_power_score(slug_b, slug_a, rng)

        winner = "draw"
        if slug_a_result["score"] > slug_b_result["score"]:
            slug_a_points += 1
            winner = slug_a.get("slug-name", "")
        elif slug_b_result["score"] > slug_a_result["score"]:
            slug_b_points += 1
            winner = slug_b.get("slug-name", "")

        rounds_data.append(
            {
                "round": round_number,
                "slug_a": {
                    "name": slug_a.get("slug-name", ""),
                    "score": slug_a_result["score"],
                    "breakdown": slug_a_result["breakdown"],
                },
                "slug_b": {
                    "name": slug_b.get("slug-name", ""),
                    "score": slug_b_result["score"],
                    "breakdown": slug_b_result["breakdown"],
                },
                "winner": winner,
            }
        )

    if slug_a_points > slug_b_points:
        duel_winner = slug_a.get("slug-name", "")
    elif slug_b_points > slug_a_points:
        duel_winner = slug_b.get("slug-name", "")
    else:
        duel_winner = "draw"

    return {
        "rounds": rounds_data,
        "scoreboard": {
            slug_a.get("slug-name", "slug_a"): slug_a_points,
            slug_b.get("slug-name", "slug_b"): slug_b_points,
        },
        "winner": duel_winner,
    }


def _filter_slugs(search_index, search="", element="", rarity="", power_type=""):
    search = _normalize(search)
    element = _normalize(element)
    rarity = _normalize(rarity)
    power_type = _normalize(power_type)

    filtered_slugs = []
    for indexed_slug in search_index:
        slug_name = indexed_slug["slug_name"]
        slug_element = indexed_slug["element"]
        slug_rarity = indexed_slug["rarity"]
        slug_power_type = indexed_slug["power_type"]

        if search and search not in slug_name:
            continue
        if element and element != slug_element:
            continue
        if rarity and rarity != slug_rarity:
            continue
        if power_type and power_type not in slug_power_type:
            continue

        filtered_slugs.append(indexed_slug["slug"])

    return filtered_slugs


def _build_stats(slugs):
    elements = Counter()
    rarities = Counter()
    power_types = Counter()

    for slug in slugs:
        info = slug.get("info", {})
        element = info.get("element") or "Unknown"
        rarity = info.get("rarity") or "Unknown"
        power_type = info.get("power_type") or "Unknown"

        elements[element] += 1
        rarities[rarity] += 1
        power_types[power_type] += 1

    return {
        "total_slugs": len(slugs),
        "elements": dict(sorted(elements.items())),
        "rarities": dict(sorted(rarities.items())),
        "power_types": dict(sorted(power_types.items())),
    }


def _get_page_size(request):
    requested_page_size = request.query_params.get("page_size")
    if not requested_page_size:
        return PAGE_SIZE

    try:
        return max(1, min(int(requested_page_size), MAX_PAGE_SIZE))
    except (TypeError, ValueError):
        return PAGE_SIZE

@api_view(["GET"])
def home(request):
    dataset = _load_slugs_data()
    return Response(
        {
            "message": "Welcome to the SlugTerra API.",
            "total_slugs": len(dataset["slugs"]),
            "endpoints": {
                "list": "/api/slugs/",
                "detail": "/api/slugs/<slug-name>/",
                "stats": "/api/slugs/stats/",
                "duel": "/api/slugs/duel/?slug_a=Aquabeek&slug_b=Infurnus&rounds=3&seed=42",
                "swagger": "/swagger/",
                "redoc": "/redoc/",
            },
        }
    )


@api_view(["GET"])
def slugs_list(request):
    """Return slugs with optional filtering and pagination."""
    dataset = _load_slugs_data()
    slugs = _filter_slugs(
        dataset["search_index"],
        search=request.query_params.get("search", ""),
        element=request.query_params.get("element", ""),
        rarity=request.query_params.get("rarity", ""),
        power_type=request.query_params.get("power_type", ""),
    )

    paginator = PageNumberPagination()
    paginator.page_size = _get_page_size(request)
    page = paginator.paginate_queryset(slugs, request)
    if page is not None:
        return paginator.get_paginated_response(page)

    return Response({"count": len(slugs), "results": slugs})


@api_view(["GET"])
def slugs_stats(request):
    dataset = _load_slugs_data()
    return Response(dataset["stats"])


@api_view(["GET"])
def slugs_duel(request):
    slug_a_name = request.query_params.get("slug_a", "")
    slug_b_name = request.query_params.get("slug_b", "")

    if not slug_a_name or not slug_b_name:
        return Response(
            {"detail": "Both query parameters slug_a and slug_b are required."},
            status=400,
        )

    rounds = _safe_int(request.query_params.get("rounds", 3), 3)
    rounds = max(1, min(rounds, 9))
    seed = _safe_int(request.query_params.get("seed", 0), 0)

    dataset = _load_slugs_data()
    slug_a = _find_slug(dataset["slug_map"], slug_a_name)
    slug_b = _find_slug(dataset["slug_map"], slug_b_name)

    if not slug_a or not slug_b:
        return Response(
            {"detail": "One or both slugs were not found."},
            status=404,
        )

    simulation = _simulate_duel(slug_a, slug_b, rounds, seed)

    return Response(
        {
            "slug_a": slug_a.get("slug-name", ""),
            "slug_b": slug_b.get("slug-name", ""),
            "rounds_requested": rounds,
            "seed": seed,
            "result": simulation,
        }
    )


@api_view(["GET"])
def slug_detail(request, slug_name):
    """Return one slug by exact name (case-insensitive)."""
    dataset = _load_slugs_data()
    slug = _find_slug(dataset["slug_map"], slug_name)
    if slug:
        return Response(slug)

    return Response({"detail": "Slug not found."}, status=404)