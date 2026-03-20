from typing import Annotated, Literal, Union
from pydantic import BaseModel, Discriminator, Field, Tag
from generator.params import ParamSpace, ParamKey


# --- Features ---

class ConstantFeatGen(BaseModel):
    feature: Literal["constant"]
    id: str | ParamKey
    constant: float | ParamKey

class RawReturnsFeatGen(BaseModel):
    feature: Literal["raw_returns"]
    id: str | ParamKey
    returns_type: str | ParamKey
    ohlc: str | ParamKey

FeatureGen = Annotated[
    Union[
        Annotated[ConstantFeatGen, Tag("constant")],
        Annotated[RawReturnsFeatGen, Tag("raw_returns")]
    ],
    Discriminator("feature")
]


# --- Node Pointer ---

class NodePtrGen(BaseModel):
    anchor: str | ParamKey
    idx: int | ParamKey


# --- Logic Nodes ---

class InputNodeGen(BaseModel):
    type: Literal["input"]
    threshold: float | ParamKey | None
    feat_idx: int | ParamKey | None

class GateNodeGen(BaseModel):
    type: Literal["gate"]
    gate: str | ParamKey | None
    in1_idx: int | ParamKey | None
    in2_idx: int | ParamKey | None

LogicNodeGen = Annotated[
    Union[
        Annotated[InputNodeGen, Tag("input")],
        Annotated[GateNodeGen, Tag("gate")]
    ],
    Discriminator("type")
]


# --- Decision Nodes ---

class BranchNodeGen(BaseModel):
    type: Literal["branch"]
    threshold: float | ParamKey | None
    feat_idx: int | ParamKey | None
    true_idx: int | ParamKey | None
    false_idx: int | ParamKey | None

class RefNodeGen(BaseModel):
    type: Literal["ref"]
    ref_idx: int | ParamKey | None
    true_idx: int | ParamKey | None
    false_idx: int | ParamKey | None

DecisionNodeGen = Annotated[
    Union[
        Annotated[BranchNodeGen, Tag("branch")],
        Annotated[RefNodeGen, Tag("ref")]
    ],
    Discriminator("type")
]


# --- Networks ---

class LogicNetGen(BaseModel):
    node_pool: list[LogicNodeGen]
    node_selection: list[int] | ParamKey
    default_value: bool | ParamKey

class DecisionNetGen(BaseModel):
    node_pool: list[DecisionNodeGen]
    node_selection: list[int] | ParamKey
    default_value: bool | ParamKey
    max_trail_len: int | ParamKey

class NetworkGen(BaseModel):
    net_type: str | ParamKey
    logic_net: LogicNetGen | None
    decision_net: DecisionNetGen | None


# --- Penalties ---

class LogicPenaltiesGen(BaseModel):
    type: Literal["logic"]
    node: float | ParamKey
    input: float | ParamKey
    gate: float | ParamKey
    recurrence: float | ParamKey
    feedforward: float | ParamKey
    used_feat: float | ParamKey
    unused_feat: float | ParamKey

class DecisionPenaltiesGen(BaseModel):
    type: Literal["decision"]
    node: float | ParamKey
    branch: float | ParamKey
    ref_: float | ParamKey = Field(alias="ref")
    leaf: float | ParamKey
    non_leaf: float | ParamKey
    used_feat: float | ParamKey
    unused_feat: float | ParamKey

PenaltiesGen = Annotated[
    Union[
        Annotated[LogicPenaltiesGen, Tag("logic")],
        Annotated[DecisionPenaltiesGen, Tag("decision")]
    ],
    Discriminator("type")
]


# --- Actions ---

class ThresholdRangeGen(BaseModel):
    feat_id: str | ParamKey
    min: float | ParamKey
    max: float | ParamKey

class MetaActionGen(BaseModel):
    label: str | ParamKey
    sub_actions: list | ParamKey

class LogicActionsGen(BaseModel):
    type: Literal["logic"]
    meta_action_pool: list[MetaActionGen]
    meta_action_selection: list[int] | ParamKey
    threshold_pool: list[ThresholdRangeGen]
    threshold_selection: list[int] | ParamKey
    n_thresholds: int | ParamKey
    allow_recurrence: bool | ParamKey
    allowed_gates: list | ParamKey

class DecisionActionsGen(BaseModel):
    type: Literal["decision"]
    meta_action_pool: list[MetaActionGen]
    meta_action_selection: list[int] | ParamKey
    threshold_pool: list[ThresholdRangeGen]
    threshold_selection: list[int] | ParamKey
    n_thresholds: int | ParamKey
    allow_refs: bool | ParamKey

ActionsGen = Annotated[
    Union[
        Annotated[LogicActionsGen, Tag("logic")],
        Annotated[DecisionActionsGen, Tag("decision")]
    ],
    Discriminator("type")
]


# --- Stop Conditions ---

class StopCondsGen(BaseModel):
    max_iters: int | ParamKey
    train_patience: int | ParamKey
    val_patience: int | ParamKey


# --- Optimizer ---

class GeneticOptGen(BaseModel):
    type: Literal["genetic"]
    pop_size: int | ParamKey
    seq_len: int | ParamKey
    n_elites: int | ParamKey
    mut_rate: float | ParamKey
    cross_rate: float | ParamKey
    tournament_size: int | ParamKey


# --- Entry / Exit Schemas ---

class EntrySchemaGen(BaseModel):
    node_ptr: NodePtrGen
    position_size: float | ParamKey
    max_positions: int | ParamKey

class ExitSchemaGen(BaseModel):
    node_ptr: NodePtrGen
    entry_indices: list | ParamKey
    stop_loss: float | ParamKey
    take_profit: float | ParamKey
    max_hold_time: int | ParamKey


# --- Backtest Schema ---

class BacktestSchemaGen(BaseModel):
    start_offset: int | ParamKey
    start_balance: float | ParamKey
    delay: int | ParamKey


# --- Strategy ---

class StrategyGen(BaseModel):
    base_net: NetworkGen
    feat_pool: list[FeatureGen]
    feat_selection: list[int] | ParamKey
    actions: ActionsGen
    penalties: PenaltiesGen
    stop_conds: StopCondsGen
    opt: GeneticOptGen
    entry_pool: list[EntrySchemaGen]
    entry_selection: list[int] | ParamKey
    exit_pool: list[ExitSchemaGen]
    exit_selection: list[int] | ParamKey


# --- Experiment ---

class ExperimentGen(BaseModel):
    params: ParamSpace
    title: str | ParamKey
    val_size: float | ParamKey
    test_size: float | ParamKey
    cv_folds: int | ParamKey
    fold_size: float | ParamKey
    backtest_schema: BacktestSchemaGen
    strategy: StrategyGen
