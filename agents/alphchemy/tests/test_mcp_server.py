from __future__ import annotations

import anyio
from mcp.shared.memory import create_connected_server_and_client_session
from mcp_server.server import mcp


def test_mcp_server_tools():
    async def run():
        async with create_connected_server_and_client_session(mcp) as session:
            await session.initialize()

            tools = await session.list_tools()
            tool_names = [tool.name for tool in tools.tools]
            assert "get_documentation" in tool_names
            assert "queue_experiment" in tool_names
            assert "search_experiments" in tool_names
            assert "analyze_experiments" in tool_names
            assert "get_experiment" in tool_names

            doc_result = await session.call_tool("get_documentation", {})
            doc_text = doc_result.content[0].text
            assert "# Alphchemy" in doc_text
            assert "Experiment JSON schema" in doc_text

    anyio.run(run)
