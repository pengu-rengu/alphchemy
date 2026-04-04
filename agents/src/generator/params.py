import itertools
from typing import Any, Generator
from pydantic import BaseModel


class ParamKey(BaseModel):
    key: str


class ParamSpace(BaseModel):
    search_space: dict[str, list]

    POOL_FIELDS_MAP: dict[str, tuple[str, str]] = {
        "node_pool": ("node_selection", "nodes"),
        "feat_pool": ("feat_selection", "feats"),
        "entry_pool": ("entry_selection", "entry_schemas"),
        "exit_pool": ("exit_selection", "exit_schemas"),
        "meta_action_pool": ("meta_action_selection", "meta_actions"),
        "threshold_pool": ("threshold_selection", "thresholds")
    }
    MERGE_FIELDS: set[str] = {
        "logic_net", "decision_net",
        "logic_actions", "decision_actions",
        "logic_penalties", "decision_penalties"
    }

    def generate_combinations(self) -> Generator[dict[str, Any], None, None]:
        keys = list(self.search_space.keys())
        values = [self.search_space[key] for key in keys]
        for combo in itertools.product(*values):
            zipped = zip(keys, combo)
            yield dict(zipped)

    def resolve_value(self, value: Any, params: dict[str, Any]) -> Any:
        if isinstance(value, ParamKey):
            return params[value.key]
        return value

    def resolve_pool(self, pool: list[BaseModel], selection: Any, params: dict[str, Any]) -> list[dict]:
        items_by_id: dict[str, dict[str, Any]] = {}

        for item in pool:
            resolved_item = self.resolve_model(item, params)
            item_id = resolved_item.get("id")

            if not isinstance(item_id, str) or not item_id:
                raise ValueError("pool item id must resolve to a non-empty string")

            if item_id in items_by_id:
                raise ValueError(f"duplicate pool id: {item_id}")

            items_by_id[item_id] = resolved_item

        resolved_selection = self.resolve_value(selection, params)
        picked = []

        for selected_id in resolved_selection:
            resolved_item = items_by_id.get(selected_id)

            if resolved_item is None:
                raise ValueError(f"selected pool id not found: {selected_id}")

            picked.append(resolved_item)

        return picked

    def apply_merges(self, result: dict[str, Any]) -> dict[str, Any]:
        merge_type = result.get("type")
        for field in self.MERGE_FIELDS:
            if field not in result:
                continue
            sub_result = result.pop(field)
            is_active = merge_type is not None and field.startswith(merge_type)
            if is_active and sub_result is not None:
                result.update(sub_result)
        return result

    def resolve_model(self, model: BaseModel, params: dict[str, Any]) -> dict[str, Any]:
        result = {}
        fields = type(model).model_fields
        pool_keys: set[str] = set()

        for pool_name, (sel_name, out_name) in self.POOL_FIELDS_MAP.items():
            if pool_name not in fields:
                continue
            pool_keys.add(pool_name)
            pool_keys.add(sel_name)
            pool = getattr(model, pool_name)
            selection = getattr(model, sel_name)
            result[out_name] = self.resolve_pool(pool, selection, params)

        for name in fields:
            if name in pool_keys:
                continue
            value = getattr(model, name)
            if value is None:
                result[name] = None
            elif isinstance(value, ParamKey):
                result[name] = params[value.key]
            elif isinstance(value, BaseModel):
                result[name] = self.resolve_model(value, params)
            else:
                result[name] = value

        return self.apply_merges(result)

    def generate_experiments(self, experiment_gen: BaseModel, max_experiments: int) -> list[dict[str, Any]]:
        from generator.verify import validate_schema
        validate_schema(experiment_gen, self.search_space)
        combinations = self.generate_combinations()
        sliced = itertools.islice(combinations, max_experiments)
        return [self.resolve_model(experiment_gen, params) for params in sliced]
