from agents.state import Message, OutputItem

def format_output_items(items: list[OutputItem]) -> str:
    return "\n".join(f"[{item['tag']}] {item['content']}" for item in items)

def format_messages(messages: list[Message]) -> str:

    text = ""
    for message in messages:
        role = message["role"]

        text += f"** ROLE: {role.upper()} **\n\n"

        if role == "assistant":
            text += message["model_output"]
        elif role == "user":
            personal = format_output_items(message["personal_output"])
            global_part = format_output_items(message["global_output"])
            text += f"PERSONAL OUTPUT:\n\n{personal}\n\nGLOBAL OUTPUT:\n\n{global_part}"

        text += "\n\n"

    return text
