from pathlib import Path
from flask import Flask, Response, abort, jsonify

DOCS_ROOT: Path = Path(__file__).parent / "docs"

DOC_PATHS: dict[str, str] = {
    "Overview":         "index.md",
    "Results":          "results.md",
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
    "Overview":   ["Overview", "Results"],
    "Experiment": ["Experiment", "Backtest", "Strategy", "Overfitting"],
    "Features":   ["Features", "Indicators"],
    "Network":    ["Network", "Logic Network", "Decision Network"],
    "Actions":    ["Actions", "Logic Actions", "Decision Actions"],
    "Optimizer":  ["Optimizer", "Genetic"]
}

app: Flask = Flask(__name__)
app.json.sort_keys = False


@app.after_request
def add_cors(response: Response) -> Response:
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.route("/index")
def index() -> Response:
    return jsonify(GROUPS)


@app.route("/doc/<doc_id>")
def serve_doc(doc_id: str) -> Response:
    if doc_id not in DOC_PATHS:
        abort(404)
    target: Path = DOCS_ROOT / DOC_PATHS[doc_id]
    text: str = target.read_text(encoding="utf-8")
    return Response(text, mimetype="text/markdown; charset=utf-8")


def main() -> None:
    app.run(host="0.0.0.0", port=5050)


if __name__ == "__main__":
    main()
