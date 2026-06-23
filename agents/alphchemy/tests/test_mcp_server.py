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
            assert "add" in tool_names
            assert "echo" in tool_names

            add_result = await session.call_tool("add", {"first": 2, "second": 3})
            assert add_result.content[0].text == "5"

            echo_result = await session.call_tool("echo", {"text": "ping"})
            assert echo_result.content[0].text == "ping"

    anyio.run(run)
