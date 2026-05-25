import "package:alphchemy/blocs/experiments/pinescript_bloc.dart";
import "package:alphchemy/blocs/experiments/results_bloc.dart";
import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/experiment_tree.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final String title;
  final int experimentId;

  const ResultsPage({super.key, required this.experimentId, required this.title});

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (blocContext) {
            final bloc = ResultsBloc(client: client);
            final event = LoadResults(experimentId: experimentId);
            bloc.add(event);
            return bloc;
          }
        ),
        BlocProvider(
          create: (blocContext) => PinescriptBloc(client: client)
        )
      ],
      child: PinescriptListener(child: Scaffold(
        body: SafeArea(
          child: ResultsArea(title: title)
        )
      ))
    );
  }
}

class ResultsArea extends StatelessWidget {
  final String title;

  const ResultsArea({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ResultsBloc, ResultsState>(
      builder: (context, state) {
        return Column(
          children: [
            ResultsHeader(title: title),
            const Divider(height: 1),
            switch (state) {
              ResultsInitial() => const LoadingIndicator(),
              ResultsError() => CenterText(state.message, expanded: true),
              // ignore: prefer_const_constructors
              ResultsLoaded() => Expanded(child: ResultsContent())
            }
          ]
        );
      }
    );
  }
}

class PinescriptListener extends StatelessWidget {
  final Widget child;

  const PinescriptListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PinescriptBloc, PinescriptState>(
      listener: (context, state) async {
        if (state is PinescriptCompleted) {
          await showDialog<void>(
            context: context,
            builder: (_) => PinescriptDialog(pinescript: state.pinescript)
          );
          if (context.mounted) _resetPinescript(context);
        } else if (state is PinescriptError) {
          await errorDialog(context: context, message: state.message);
          if (context.mounted) _resetPinescript(context);
        }
      },
      child: child
    );
  }

  void _resetPinescript(BuildContext context) => context.read<PinescriptBloc>().add(const ResetPinescript());
}

class ResultsContent extends StatelessWidget {
  const ResultsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<ResultsBloc>().state as ResultsLoaded;

    final results = state.results;
    return ResultsDashboard(
      title: results.title,
      folds: results.folds,
      experiment: results.experiment,
      foldIdx: state.foldIdx
    );
  }
}

class ResultsHeader extends StatelessWidget {
  final String title;

  const ResultsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final state = context.read<ResultsBloc>().state;
    final loaded = state is ResultsLoaded ? state : null;

    return Header(
      left: [
        IconButton(
          icon: const NormalIcon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop()
        ),
        const SizedBox(width: 10.0),
        LargeText(title)
      ],
      right: loaded == null ? [] : [
        // ignore: prefer_const_constructors
        PinescriptButton(),
        const SizedBox(width: 10.0),
        ExperimentConfigButton(experiment: loaded.results.experiment)
      ],
      errorMessage: loaded?.errorMessage
    );
  }
}

class PinescriptButton extends StatelessWidget {
  const PinescriptButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PinescriptBloc, PinescriptState>(
      builder: (context, state) {
        final working = state is PinescriptWorking;

        return FilledButton.icon(
          onPressed: working ? null : () {
            final resultsState = context.read<ResultsBloc>().state;

            if (resultsState is! ResultsLoaded) {
              throw StateError("PineScript conversion requires loaded results");
            }

            final event = ConvertPinescript(
              experimentId: resultsState.experimentId,
              foldIdx: resultsState.foldIdx
            );
            context.read<PinescriptBloc>().add(event);
          },
          icon: InvertedIcon(working ? Icons.hourglass_top : Icons.code),
          label: InvertedText(working ? "Converting..." : "Convert to PineScript")
        );
      }
    );
  }
}

class PinescriptDialog extends StatefulWidget {
  final String pinescript;

  const PinescriptDialog({super.key, required this.pinescript});

  @override
  State<PinescriptDialog> createState() => _PinescriptDialogState();
}

class _PinescriptDialogState extends State<PinescriptDialog> {
  final ScrollController _scrollController = ScrollController();
  bool _copied = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: const LargeText("Pinescript code"),
      content: SizedBox(
        width: size.width * 0.8,
        height: size.height,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: PaddedCard(child: NormalText(widget.pinescript))
          )
        )
      ),
      actions: [
        FilledButton.icon(
          onPressed: () async {
            final data = ClipboardData(text: widget.pinescript);
            await Clipboard.setData(data);
            setState(() {
              _copied = true;
            });
          },
          icon: InvertedIcon(_copied ? Icons.check : Icons.copy),
          label: InvertedText(_copied ? "Copied" : "Copy")
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const InvertedText("Close")
        )
      ]
    );
  }
}

class ExperimentConfigButton extends StatelessWidget {
  final Experiment experiment;

  const ExperimentConfigButton({super.key, required this.experiment});

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: () {
        final size = MediaQuery.of(context).size;
        showDialog<void>(
          context: context,
          builder: (innerContext) => AlertDialog(
            title: const LargeText("Experiment Configuration"),
            content: SizedBox(
              width: size.width * 0.8,
              height: size.height,
              child: ExperimentTree(tree: buildExperimentTree(experiment), readOnly: true)
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const InvertedText("Close")
              )
            ]
          )
        );
      },
      icon: const InvertedIcon(Icons.account_tree),
      label: const InvertedText("View Experiment Configuration")
    );
  }
}
