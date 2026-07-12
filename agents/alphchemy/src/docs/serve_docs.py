from pathlib import Path, PurePosixPath
from flask import Flask, Response, abort, jsonify

DOCS_ROOT: Path = Path(__file__).parent

DOC_PATHS: dict[str, str] = {
    "Overview":         "overview.md",
    "Results":          "results.md",
    "Notebooks":        "notebooks.md",
    "Source Format":    "source/source_format.md",
    "Example":          "source/example.md",
    "Experiment":       "experiment/experiment.md",
    "Backtest":         "experiment/backtest.md",
    "Strategy":         "experiment/strategy.md",
    "Overfitting":      "experiment/overfitting.md",
    "Features":         "features/features.md",
    "Indicators":       "features/indicators.md",
    "Network":          "network/network.md",
    "Logic Network":        "network/logic_net.md",
    "Decision Network":     "network/decision_net.md",
    "Actions":          "actions/actions.md",
    "Logic Actions":    "actions/logic_actions.md",
    "Decision Actions": "actions/decision_actions.md",
    "Optimizer":        "optimizer/optimizer.md",
    "Genetic":          "optimizer/genetic.md"
}

GROUPS: dict[str, list[str]] = {
    "Overview":   ["Overview", "Results", "Notebooks"],
    "Experiment": ["Experiment", "Source Format", "Example", "Backtest", "Strategy", "Overfitting"],
    "Features":   ["Features", "Indicators"],
    "Network":    ["Network", "Logic Network", "Decision Network"],
    "Actions":    ["Actions", "Logic Actions", "Decision Actions"],
    "Optimizer":  ["Optimizer", "Genetic"]
}

app: Flask = Flask(__name__)
app.json.sort_keys = False


def list_doc_paths() -> list[str]:
    doc_paths = set(DOC_PATHS.values())
    sorted_paths = sorted(doc_paths)
    paths = []

    for doc_path in sorted_paths:
        path = doc_path.removesuffix(".md")
        paths.append(path)

    return paths


def read_doc(doc_path: str) -> str:
    requested = PurePosixPath(doc_path)

    if requested.is_absolute() or ".." in requested.parts:
        raise ValueError("doc_path must be relative to docs")

    target = DOCS_ROOT.joinpath(*requested.parts)
    target_text = f"{target}.md"
    target = Path(target_text)

    if not target.is_file():
        raise FileNotFoundError(doc_path)

    return target.read_text(encoding="utf-8")


@app.after_request
def add_cors(response: Response) -> Response:
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route("/index")
def index() -> Response:
    return jsonify(GROUPS)


@app.route("/directory")
def directory() -> Response:
    doc_paths = list_doc_paths()
    return jsonify(doc_paths)


@app.route("/doc/<doc_id>")
def serve_doc(doc_id: str) -> Response:
    if doc_id not in DOC_PATHS:
        abort(404)
    target: Path = DOCS_ROOT / DOC_PATHS[doc_id]
    text: str = target.read_text(encoding="utf-8")
    return Response(text, mimetype="text/markdown; charset=utf-8")


@app.route("/docs/<path:doc_path>")
def serve_path_doc(doc_path: str) -> Response:
    requested = PurePosixPath(doc_path)

    if requested.is_absolute() or ".." in requested.parts:
        abort(400, "doc_path must be relative to docs")

    if requested.suffix != ".md":
        abort(400, "doc_path must end with .md")

    target = DOCS_ROOT.joinpath(*requested.parts)
    if not target.is_file():
        abort(404)

    text: str = target.read_text(encoding="utf-8")
    return Response(text, mimetype="text/markdown; charset=utf-8")


def main() -> None:
    app.run(host="0.0.0.0", port=5050)


if __name__ == "__main__":
    main()
