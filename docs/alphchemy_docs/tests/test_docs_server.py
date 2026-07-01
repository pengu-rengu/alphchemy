from __future__ import annotations

import unittest

from main import app


class DocsServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = app.test_client()

    def test_directory_lists_markdown_paths(self) -> None:
        response = self.client.get("/directory")
        doc_paths = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertIn("experiment/backtest.md", doc_paths)
        self.assertIn("source/source_format.md", doc_paths)
        self.assertIn("notebooks.md", doc_paths)

    def test_docs_route_serves_markdown_by_path(self) -> None:
        response = self.client.get("/docs/experiment/backtest.md")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Backtest", body)

    def test_docs_route_serves_notebooks_doc(self) -> None:
        response = self.client.get("/docs/notebooks.md")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Notebook Description", body)

    def test_docs_route_rejects_traversal(self) -> None:
        response = self.client.get("/docs/%2E%2E/AGENTS.md")

        self.assertEqual(response.status_code, 400)

    def test_docs_route_rejects_non_markdown(self) -> None:
        response = self.client.get("/docs/index.txt")

        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
