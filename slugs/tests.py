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

    def test_slug_detail_returns_matching_slug(self):
        response = self.client.get("/api/slugs/Air Elemental/")

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["slug-name"], "Air Elemental")

    def test_slug_stats_returns_counts(self):
        response = self.client.get("/api/slugs/stats/")

        self.assertEqual(response.status_code, 200)
        self.assertIn("total_slugs", response.data)
        self.assertIn("elements", response.data)
