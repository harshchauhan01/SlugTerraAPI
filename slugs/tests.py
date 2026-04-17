from django.test import TestCase
from rest_framework.test import APIClient


class SlugsApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def test_home_returns_summary(self):
        response = self.client.get("/")

        self.assertEqual(response.status_code, 200)
        self.assertIn("message", response.data)
        self.assertIn("total_slugs", response.data)

    def test_slug_list_supports_search(self):
        response = self.client.get("/api/slugs/", {"search": "Air Elemental"})

        self.assertEqual(response.status_code, 200)
        self.assertGreaterEqual(response.data["count"], 1)

    def test_slug_list_caps_page_size(self):
        response = self.client.get("/api/slugs/", {"page_size": 10000})

        self.assertEqual(response.status_code, 200)
        self.assertLessEqual(len(response.data["results"]), 100)

    def test_slug_detail_returns_matching_slug(self):
        response = self.client.get("/api/slugs/Air Elemental/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["slug-name"], "Air Elemental")

    def test_slug_stats_returns_counts(self):
        response = self.client.get("/api/slugs/stats/")

        self.assertEqual(response.status_code, 200)
        self.assertIn("total_slugs", response.data)
        self.assertIn("elements", response.data)

    def test_slug_duel_returns_simulation(self):
        response = self.client.get(
            "/api/slugs/duel/",
            {"slug_a": "Aquabeek", "slug_b": "Infurnus", "rounds": 3, "seed": 7},
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["slug_a"], "Aquabeek")
        self.assertEqual(response.data["slug_b"], "Infurnus")
        self.assertEqual(response.data["rounds_requested"], 3)
        self.assertEqual(len(response.data["result"]["rounds"]), 3)
        self.assertIn("winner", response.data["result"])

    def test_slug_duel_requires_both_slugs(self):
        response = self.client.get("/api/slugs/duel/", {"slug_a": "Aquabeek"})

        self.assertEqual(response.status_code, 400)
        self.assertIn("detail", response.data)

    def test_slug_duel_returns_not_found(self):
        response = self.client.get(
            "/api/slugs/duel/",
            {"slug_a": "Unknown One", "slug_b": "Infurnus"},
        )

        self.assertEqual(response.status_code, 404)
        self.assertIn("detail", response.data)
