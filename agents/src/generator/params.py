import itertools
from typing import Any, Generator
from pydantic import BaseModel


class ParamKey(BaseModel):
    key: str


class ParamSpace(BaseModel):
    search_space: dict[str, list]

    POOL_SELECTION_MAP: dict[str, tuple[str, str]] = {
        "node_pool": ("node_selection", "nodes"),
        "feat_pool": ("feat_selection", "feats"),
        "entry_pool": ("entry_selection", "entry_schemas"),
        "exit_pool": ("exit_selection", "exit_schemas"),
        "meta_action_pool": ("meta_action_selection", "meta_actions"),
        "threshold_pool": ("threshold_selection", "thresholds")
    }

    STRIP_FIELDS: set[str] = {"params"}
    RENAME_FIELDS: dict[str, str] = {"ref_": "ref"}
    MERGE_FIELDS: set[str] = {"logic_net", "decision_net"}

    def resolve_value(self, value: Any) -> list[Any]:
        if isinstance(value, ParamKey):
            return self.search_space[value.key]
        return [value]

    def resolve_pool(self, pool: list[BaseModel], selection_val: Any) -> Generator[list[Any], None, None]:
        selections = self.resolve_value(selection_val)
        for selection in selections:
            picked = [pool[i] for i in selection]
            resolved_items = []
            for item in picked:
                resolved = self.resolve_model(item)
                resolved_items.append(list(resolved))

            for combination in itertools.product(*resolved_items):
                yield list(combination)

    @staticmethod
    def apply_merges(result: dict[str, Any]) -> dict[str, Any]:
        merge_fields = {"logic_net", "decision_net"}
        for field in merge_fields:
            if field not in result:
                continue
            sub = result.pop(field)
            if sub is not None:
                result.update(sub)
        return result

    def resolve_model(self, model: BaseModel) -> Generator[dict[str, Any], None, None]:
        fields = {}
        model_data = type(model).model_fields
        pool_keys: set[str] = set()

        for pool_name, (selection_name, out_name) in self.POOL_SELECTION_MAP.items():
            if pool_name not in model_data:
                continue
            pool_keys.add(pool_name)
            pool_keys.add(selection_name)

            pool = getattr(model, pool_name)
            selection_value = getattr(model, selection_name)
            resolved = self.resolve_pool(pool, selection_value)
            fields[out_name] = list(resolved)

        for name in model_data:
            if name in pool_keys:
                continue

            value = getattr(model, name)
            if value is None:
                fields[name] = [None]
            elif isinstance(value, ParamKey):
                fields[name] = self.resolve_value(value)
            elif isinstance(value, BaseModel):
                resolved = self.resolve_model(value)
                fields[name] = list(resolved)
            elif isinstance(value, list):
                fields[name] = [value]
            else:
                fields[name] = self.resolve_value(value)

        ordered_names = list(fields.keys())
        ordered_values = [fields[name] for name in ordered_names]

        for combination in itertools.product(*ordered_values):
            result = {}
            for name, val in zip(ordered_names, combination):
                out_name = self.RENAME_FIELDS.get(name, name)
                result[out_name] = val
            result = self.apply_merges(result)
            yield result

    def generate_experiments(self, experiment_gen: BaseModel, max_experiments: int) -> list[dict[str, Any]]:
        resolved = self.resolve_model(experiment_gen)
        sliced = itertools.islice(resolved, max_experiments)
        experiments = list(sliced)
        for exp in experiments:
            for field in self.STRIP_FIELDS:
                exp.pop(field, None)
        return experiments
