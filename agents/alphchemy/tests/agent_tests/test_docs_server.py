from __future__ import annotations

import unittest

from docs.serve_docs import app, read_doc


class DocsServerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.client = app.test_client()

    def test_directory_lists_doc_paths(self) -> None:
        response = self.client.get("/directory")
        doc_paths = response.get_json()

        self.assertEqual(response.status_code, 200)
        self.assertIn("overview", doc_paths)
        self.assertNotIn("index", doc_paths)
        self.assertIn("experiment/backtest", doc_paths)
        self.assertIn("source/source_format", doc_paths)
        self.assertIn("source/example", doc_paths)
        self.assertIn("notebooks", doc_paths)

    def test_index_lists_example(self) -> None:
        response = self.client.get("/index")
        groups = response.get_json()

        self.assertEqual(groups["Experiment"][2], "Example")

    def test_read_doc_uses_extensionless_path(self) -> None:
        body = read_doc("experiment/backtest")

        self.assertIn("# Backtest", body)

    def test_read_doc_does_not_accept_markdown_extension(self) -> None:
        with self.assertRaises(FileNotFoundError):
            read_doc("experiment/backtest.md")

    def test_doc_route_serves_overview(self) -> None:
        response = self.client.get("/doc/Overview")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Overview", body)
        self.assertIn("This page describes **Alphchemy**", body)

    def test_doc_route_serves_example(self) -> None:
        response = self.client.get("/doc/Example")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Example", body)
        self.assertIn("total_entries, total_exits", body)
        self.assertIn("mean_hold_time, std_hold_time", body)

    def test_docs_route_serves_markdown_by_path(self) -> None:
        response = self.client.get("/docs/experiment/backtest.md")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Backtest", body)

    def test_docs_route_serves_notebooks_doc(self) -> None:
        response = self.client.get("/docs/notebooks.md")
        body = response.get_data(as_text=True)

        self.assertEqual(response.status_code, 200)
        self.assertIn("# Notebooks", body)

    def test_docs_route_rejects_traversal(self) -> None:
        response = self.client.get("/docs/%2E%2E/AGENTS.md")

        self.assertEqual(response.status_code, 400)

    def test_docs_route_rejects_non_markdown(self) -> None:
        response = self.client.get("/docs/index.txt")

        self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
