from generator.params import ParamSpace, ParamKey
from generator.generator import (
    ExperimentGen,
    BacktestSchemaGen,
    StrategyGen,
    NetworkGen,
    LogicNetGen,
    InputNodeGen,
    GateNodeGen,
    LogicActionsGen,
    MetaActionGen,
    ThresholdRangeGen,
    LogicPenaltiesGen,
    StopCondsGen,
    GeneticOptGen,
    EntrySchemaGen,
    ExitSchemaGen,
    NodePtrGen,
    ConstantFeatGen,
    RawReturnsFeatGen
)
import json


def build_experiment_gen() -> ExperimentGen:

    feat_pool = [
        ConstantFeatGen(
            feature="constant",
            id="const_1",
            constant=1.0
        ),
        RawReturnsFeatGen(
            feature="raw_returns",
            id="raw_ret_1",
            returns_type="log",
            ohlc="close"
        )
    ]

    node_pool = [
        InputNodeGen(type="input", threshold=0.5, feat_idx=0),
        InputNodeGen(type="input", threshold=0.3, feat_idx=1),
        GateNodeGen(type="gate", gate="and", in1_idx=0, in2_idx=1)
    ]

    logic_net = LogicNetGen(
        node_pool=node_pool,
        node_selection=ParamKey(key="node_sel"),
        default_value=ParamKey(key="default_val")
    )

    base_net = NetworkGen(
        type=ParamKey(key="net_type"),
        logic_net=logic_net,
        decision_net=None
    )

    meta_action_pool = [
        MetaActionGen(label="buy", sub_actions=ParamKey(key="sub_actions")),
        MetaActionGen(label="sell", sub_actions=["close_long"])
    ]

    threshold_pool = [
        ThresholdRangeGen(
            feat_id="const_1",
            min=0.0,
            max=ParamKey(key="threshold_val")
        )
    ]

    actions = LogicActionsGen(
        type="logic",
        meta_action_pool=meta_action_pool,
        meta_action_selection=[0, 1],
        threshold_pool=threshold_pool,
        threshold_selection=[0],
        n_thresholds=5,
        allow_recurrence=False,
        allowed_gates=["and", "or"]
    )

    penalties = LogicPenaltiesGen(
        type="logic",
        node=0.1,
        input=0.1,
        gate=0.1,
        recurrence=0.5,
        feedforward=0.1,
        used_feat=0.0,
        unused_feat=0.2
    )

    stop_conds = StopCondsGen(
        max_iters=100,
        train_patience=10,
        val_patience=5
    )

    opt = GeneticOptGen(
        type="genetic",
        pop_size=ParamKey(key="pop_size"),
        seq_len=10,
        n_elites=5,
        mut_rate=ParamKey(key="mut_rate"),
        cross_rate=0.7,
        tournament_size=3
    )

    entry_pool = [
        EntrySchemaGen(
            node_ptr=NodePtrGen(anchor="root", idx=0),
            position_size=0.1,
            max_positions=3
        )
    ]

    exit_pool = [
        ExitSchemaGen(
            node_ptr=NodePtrGen(anchor="root", idx=1),
            entry_indices=[0],
            stop_loss=0.02,
            take_profit=0.05,
            max_hold_time=100
        )
    ]

    strategy = StrategyGen(
        base_net=base_net,
        feat_pool=feat_pool,
        feat_selection=ParamKey(key="feat_sel"),
        actions=actions,
        penalties=penalties,
        stop_conds=stop_conds,
        opt=opt,
        entry_pool=entry_pool,
        entry_selection=ParamKey(key="entry_sel"),
        exit_pool=exit_pool,
        exit_selection=ParamKey(key="exit_sel")
    )

    backtest_schema = BacktestSchemaGen(
        start_offset=100,
        start_balance=10000.0,
        delay=1
    )

    return ExperimentGen(
        title="test_experiment",
        val_size=0.15,
        test_size=0.15,
        cv_folds=3,
        fold_size=0.5,
        backtest_schema=backtest_schema,
        strategy=strategy
    )


def main() -> None:
    params = ParamSpace(search_space={
        "net_type": ["logic"],
        "default_val": [True, False],
        "node_sel": [[0, 1], [0, 1, 2]],
        "feat_sel": [[0], [0, 1]],
        "entry_sel": [[0]],
        "exit_sel": [[0]],
        "threshold_val": [0.5, 0.8],
        "mut_rate": [0.1, 0.2],
        "pop_size": [50, 100],
        "sub_actions": [["a", "b"], ["b", "a"]]
    })

    experiment_gen = build_experiment_gen()
    experiments = params.generate_experiments(experiment_gen, max_experiments=10)

    print(f"Generated {len(experiments)} experiments:\n")
    for i, exp in enumerate(experiments):
        print(f"--- Experiment {i} ---")
        print(json.dumps(exp, indent=2, default=str))
        print()


if __name__ == "__main__":
    main()
