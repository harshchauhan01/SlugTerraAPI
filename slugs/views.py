import json
from collections import Counter
from pathlib import Path

from rest_framework.decorators import api_view
from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response


DATA_FILE = Path(__file__).resolve().parents[1] / "slugs_data.json"
PAGE_SIZE = 24


def _normalize(value):
    return value.strip().lower()


def _load_slugs_data():
    """Read and parse slug data from the project JSON file."""
    with DATA_FILE.open("r", encoding="utf-8") as data_file:
        return json.load(data_file)


def _filter_slugs(slugs, search="", element="", rarity="", power_type=""):
    search = _normalize(search)
    element = _normalize(element)
    rarity = _normalize(rarity)
    power_type = _normalize(power_type)

    filtered_slugs = []
    for slug in slugs:
        slug_name = slug.get("slug-name", "")
        info = slug.get("info", {})
        slug_element = info.get("element", "")
        slug_rarity = info.get("rarity", "")
        slug_power_type = info.get("power_type", "")

        if search and search not in _normalize(slug_name):
            continue
        if element and element != _normalize(slug_element):
            continue
        if rarity and rarity != _normalize(slug_rarity):
            continue
        if power_type and power_type not in _normalize(slug_power_type):
            continue

        filtered_slugs.append(slug)

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
        return max(1, int(requested_page_size))
    except (TypeError, ValueError):
        return PAGE_SIZE

@api_view(["GET"])
def home(request):
    slugs = _load_slugs_data()
    return Response(
        {
            "message": "Welcome to the SlugTerra API.",
            "total_slugs": len(slugs),
            "endpoints": {
                "list": "/api/slugs/",
                "detail": "/api/slugs/<slug-name>/",
                "stats": "/api/slugs/stats/",
                "swagger": "/swagger/",
                "redoc": "/redoc/",
            },
        }
    )


@api_view(["GET"])
def slugs_list(request):
    """Return slugs with optional filtering and pagination."""
    slugs = _load_slugs_data()
    slugs = _filter_slugs(
        slugs,
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
    slugs = _load_slugs_data()
    return Response(_build_stats(slugs))


@api_view(["GET"])
def slug_detail(request, slug_name):
    """Return one slug by exact name (case-insensitive)."""
    slugs = _load_slugs_data()
    target_name = _normalize(slug_name)

    for slug in slugs:
        if _normalize(slug.get("slug-name", "")) == target_name:
            return Response(slug)

    return Response({"detail": "Slug not found."}, status=404)