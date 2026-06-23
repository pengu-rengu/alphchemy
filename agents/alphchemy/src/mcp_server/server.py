from __future__ import annotations

from mcp.server.fastmcp import FastMCP

mcp = FastMCP("alphchemy-mcp")


@mcp.tool()
def add(first: int, second: int) -> int:
    """Add two integers."""
    return first + second


@mcp.tool()
def echo(text: str) -> str:
    """Echo back the given text."""
    return text


if __name__ == "__main__":
    mcp.run()
