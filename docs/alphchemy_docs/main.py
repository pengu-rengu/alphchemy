from pathlib import Path
from flask import Flask, Response, abort

DOCS_ROOT: Path = Path(__file__).parent / "docs"

app: Flask = Flask(__name__)


@app.route("/")
def index() -> Response:
    paths: list[str] = []
    for path in sorted(DOCS_ROOT.rglob("*.md")):
        rel: str = str(path.relative_to(DOCS_ROOT))
        paths.append(rel)
    body: str = "\n".join(paths) + "\n"
    return Response(body, mimetype="text/plain; charset=utf-8")


@app.route("/<path:doc_path>")
def serve_doc(doc_path: str) -> Response:
    if not doc_path.endswith(".md"):
        abort(404)

    requested: Path = (DOCS_ROOT / doc_path).resolve()

    if not requested.is_relative_to(DOCS_ROOT.resolve()):
        abort(404)

    if not requested.is_file():
        abort(404)

    text: str = requested.read_text(encoding="utf-8")
    return Response(text, mimetype="text/markdown; charset=utf-8")


def main() -> None:
    app.run(host="0.0.0.0", port=5050)


if __name__ == "__main__":
    main()
