from agents.state import Message

def format_messages(messages: list[Message]) -> str:

    text = ""
    for message in messages:
        role = message["role"]

        text += f"** ROLE: {role.upper()} **\n\n"

        if role == "assistant":
            text += message["model_output"]
        elif role == "user":
            text += f"PERSONAL OUTPUT:\n\n{message['personal_output']}\n\nGLOBAL OUTPUT:\n\n{message['global_output']}"

        text += "\n\n"

    return text

def format_pages(pages: list[str]) -> str:
    text = ""

    for i, page in enumerate(pages):
        text += f"__Page {i + 1}__\n"
        text += f"{page}\n\n"

    return text
