import json
from pathlib import Path

from rest_framework.decorators import api_view
from rest_framework.response import Response


DATA_FILE = Path(__file__).resolve().parents[1] / "slugs_data.json"


def _load_slugs_data():
    """Read and parse slug data from the project JSON file."""
    with DATA_FILE.open("r", encoding="utf-8") as data_file:
        return json.load(data_file)

@api_view(["GET"])
def home(request):
    return Response("Welcome, This is the home page of Slugterra API.")


@api_view(["GET"])
def slugs_list(request):
    """Return all slugs, optionally filtered by slug name using ?search=."""
    slugs = _load_slugs_data()
    search = request.query_params.get("search", "").strip().lower()

    if search:
        slugs = [
            slug
            for slug in slugs
            if search in slug.get("slug-name", "").lower()
        ]

    return Response(
        {
            "count": len(slugs),
            "results": slugs,
        }
    )


@api_view(["GET"])
def slug_detail(request, slug_name):
    """Return one slug by exact name (case-insensitive)."""
    slugs = _load_slugs_data()
    target_name = slug_name.strip().lower()

    for slug in slugs:
        if slug.get("slug-name", "").lower() == target_name:
            return Response(slug)

    return Response({"detail": "Slug not found."}, status=404)