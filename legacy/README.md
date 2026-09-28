# Legacy Python code

These directories preserve the latest versions before each component was removed. The Python files are copied verbatim from their respective snapshots.

| Directory | Source commit | Original path |
| --- | --- | --- |
| `agents/` | `638624a8295765e2d1c1835e76abd4f1f35d0637` (July 18, 2026) | `agents/alphchemy/src/agents/` |
| `ontology/` | `30146d6fd9cd817527394a8d22b4ed837d749e31` (March 27, 2026) | `agents/src/ontology/` |

`agents/` contains the LangGraph agent harness. `ontology/` contains the ontology workflow and the PyTorch `SparseAutoencoder` in `sae.py`.

This is a source archive; imports and dependencies retain their historical assumptions.
