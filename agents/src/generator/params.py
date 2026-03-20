from pydantic import BaseModel

class ParamSpace(BaseModel):
    search_space: dict[str, list]

class ParamKey(BaseModel):
    key: str